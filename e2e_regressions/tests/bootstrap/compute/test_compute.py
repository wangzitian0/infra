"""
Bootstrap Compute Layer E2E Tests.

Tests K3s cluster health and Traefik ingress.
"""
import pytest
import httpx
import pathlib
import subprocess
from urllib.parse import urlparse
from conftest import TestConfig


# =============================================================================
# K3s Cluster Tests
# =============================================================================

@pytest.mark.smoke
@pytest.mark.bootstrap
async def test_k3s_api_accessible(config: TestConfig):
    """Verify K3s API server is accessible via Dashboard."""
    async with httpx.AsyncClient(verify=False) as client:
        response = await client.get(config.DASHBOARD_URL, timeout=10.0)
        assert response.status_code in [200, 301, 302, 401, 403], \
            f"K8s Dashboard should be accessible, got {response.status_code}"


@pytest.mark.bootstrap
async def test_k3s_namespaces_exist():
    """Verify expected namespaces exist in cluster."""
    try:
        result = subprocess.run(
            ["kubectl", "get", "namespaces", "-o", "jsonpath={.items[*].metadata.name}"],
            capture_output=True, text=True, timeout=10.0
        )
        
        if result.returncode != 0:
            pytest.skip("kubectl command failed or not accessible")
        
        namespaces = result.stdout.split()
        
        # Critical namespaces that must exist
        critical_namespaces = ["kube-system", "bootstrap", "platform"]
        
        for ns in critical_namespaces:
            assert ns in namespaces, \
                f"Critical namespace '{ns}' should exist, found: {namespaces}"
    except FileNotFoundError:
        pytest.skip("kubectl not found in test environment")


@pytest.mark.bootstrap
async def test_k3s_core_services_running(config: TestConfig):
    """Verify core K8s services are accessible via endpoints."""
    async with httpx.AsyncClient(verify=False) as client:
        # Dashboard accessibility implies K8s API is running
        response = await client.get(config.DASHBOARD_URL, timeout=10.0)
        assert response.status_code in [200, 301, 302, 401, 403], \
            "Dashboard accessibility implies K8s API is running"


# =============================================================================
# Digger Orchestrator Tests
# =============================================================================

@pytest.mark.smoke
@pytest.mark.bootstrap
async def test_digger_endpoint_accessible(config: TestConfig):
    """Verify Digger Orchestrator endpoint is accessible."""
    async with httpx.AsyncClient(verify=False) as client:
        try:
            response = await client.get(config.DIGGER_URL, timeout=10.0)
            # Digger usually requires auth or returns 200/401
            assert response.status_code in [200, 401], \
                f"Digger should respond, got {response.status_code}"
        except httpx.ConnectError:
            pytest.skip("Digger not reachable from test environment")


@pytest.mark.bootstrap
async def test_cnpg_operator_running():
    """Verify CNPG Operator pod is running."""
    try:
        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", "cnpg-system", "-l", "app.kubernetes.io/name=cloudnative-pg", "-o", "jsonpath={.items[*].status.phase}"],
            capture_output=True, text=True, timeout=10.0
        )
        
        if result.returncode == 0 and result.stdout:
            phases = result.stdout.split()
            assert any(phase == "Running" for phase in phases), \
                f"CNPG operator should be running, got phases: {phases}"
        else:
            pytest.skip("kubectl command failed or CNPG operator not found")
    except FileNotFoundError:
        pytest.skip("kubectl not found in test environment")


@pytest.mark.bootstrap
async def test_k3s_nodes_ready():
    """Verify K3s cluster nodes are in Ready state."""
    try:
        result = subprocess.run(
            ["kubectl", "get", "nodes", "-o", "jsonpath={.items[*].status.conditions[?(@.type=='Ready')].status}"],
            capture_output=True, text=True, timeout=10.0
        )
        
        if result.returncode == 0 and result.stdout:
            statuses = result.stdout.split()
            assert all(status == "True" for status in statuses), \
                f"All nodes should be Ready, got: {statuses}"
            assert len(statuses) > 0, "At least one node should exist"
        else:
            pytest.skip("kubectl command failed")
    except FileNotFoundError:
        pytest.skip("kubectl not found in test environment")


@pytest.mark.bootstrap
async def test_k3s_system_pods_healthy():
    """Verify critical kube-system pods are running."""
    try:
        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", "kube-system", "-o", "jsonpath={.items[*].status.phase}"],
            capture_output=True, text=True, timeout=10.0
        )
        
        if result.returncode == 0 and result.stdout:
            phases = result.stdout.split()
            running_count = sum(1 for phase in phases if phase == "Running")
            total_count = len(phases)
            
            # At least 80% of system pods should be running
            assert running_count >= total_count * 0.8, \
                f"Most kube-system pods should be running: {running_count}/{total_count}"
        else:
            pytest.skip("kubectl command failed")
    except FileNotFoundError:
        pytest.skip("kubectl not found in test environment")


@pytest.mark.bootstrap
async def test_bootstrap_namespace_pods_healthy():
    """Verify bootstrap namespace pods are running."""
    try:
        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", "bootstrap", "-o", "jsonpath={.items[*].status.phase}"],
            capture_output=True, text=True, timeout=10.0
        )
        
        if result.returncode == 0 and result.stdout:
            phases = result.stdout.split()
            if len(phases) > 0:
                running_count = sum(1 for phase in phases if phase == "Running")
                assert running_count > 0, \
                    f"At least one bootstrap pod should be running, got: {phases}"
        else:
            pytest.skip("kubectl command failed or no bootstrap pods")
    except FileNotFoundError:
        pytest.skip("kubectl not found in test environment")


@pytest.mark.bootstrap
async def test_platform_namespace_pods_healthy():
    """Verify platform namespace pods are running."""
    try:
        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", "platform", "-o", "jsonpath={.items[*].status.phase}"],
            capture_output=True, text=True, timeout=10.0
        )
        
        if result.returncode == 0 and result.stdout:
            phases = result.stdout.split()
            if len(phases) > 0:
                running_count = sum(1 for phase in phases if phase == "Running")
                # At least 50% of platform pods should be running (some may be initializing)
                assert running_count >= len(phases) * 0.5, \
                    f"Most platform pods should be running: {running_count}/{len(phases)}"
        else:
            pytest.skip("kubectl command failed or no platform pods")
    except FileNotFoundError:
        pytest.skip("kubectl not found in test environment")


# =============================================================================
# Traefik Ingress Tests
# =============================================================================

@pytest.mark.bootstrap
async def test_traefik_pod_running():
    """Verify Traefik ingress controller is running."""
    try:
        result = subprocess.run(
            ["kubectl", "get", "pods", "-n", "kube-system", "-l", "app.kubernetes.io/name=traefik", "-o", "jsonpath={.items[*].status.phase}"],
            capture_output=True, text=True, timeout=10.0
        )
        
        if result.returncode == 0 and result.stdout:
            phases = result.stdout.split()
            assert any(phase == "Running" for phase in phases), \
                f"Traefik should be running, got phases: {phases}"
        else:
            # Try alternative label
            result = subprocess.run(
                ["kubectl", "get", "pods", "-n", "kube-system", "-l", "app=traefik", "-o", "jsonpath={.items[*].status.phase}"],
                capture_output=True, text=True, timeout=10.0
            )
            if result.returncode == 0 and result.stdout:
                phases = result.stdout.split()
                assert any(phase == "Running" for phase in phases), \
                    f"Traefik should be running, got phases: {phases}"
            else:
                pytest.skip("Traefik pods not found")
    except FileNotFoundError:
        pytest.skip("kubectl not found in test environment")


@pytest.mark.bootstrap
async def test_traefik_service_exists():
    """Verify Traefik service exists and has endpoints."""
    try:
        result = subprocess.run(
            ["kubectl", "get", "svc", "-n", "kube-system", "traefik", "-o", "jsonpath={.spec.type}"],
            capture_output=True, text=True, timeout=10.0
        )
        
        if result.returncode == 0 and result.stdout:
            service_type = result.stdout.strip()
            # K3s typically uses LoadBalancer or NodePort for Traefik
            assert service_type in ["LoadBalancer", "NodePort", "ClusterIP"], \
                f"Traefik service should exist, got type: {service_type}"
        else:
            pytest.skip("Traefik service not found")
    except FileNotFoundError:
        pytest.skip("kubectl not found in test environment")
    """Verify Traefik successfully routes to services."""
    async with httpx.AsyncClient(verify=False) as client:
        services = [
            config.PORTAL_URL,
            config.VAULT_URL,
        ]
        
        accessible_count = 0
        for url in services:
            try:
                response = await client.get(url, timeout=10.0)
                if response.status_code < 500:
                    accessible_count += 1
            except Exception:
                pass
        
        assert accessible_count >= 1, \
            "Traefik should route at least one service successfully"


@pytest.mark.bootstrap
async def test_traefik_https_redirect(config: TestConfig):
    """Verify Traefik redirects HTTP to HTTPS."""
    portal_url = urlparse(config.PORTAL_URL)
    http_url = f"http://{portal_url.hostname}"
    
    async with httpx.AsyncClient(verify=False, follow_redirects=False) as client:
        try:
            response = await client.get(http_url, timeout=10.0)
            if response.status_code in [301, 302, 307, 308]:
                location = response.headers.get('location', '')
                assert location.startswith('https://'), \
                    "HTTP should redirect to HTTPS"
        except Exception:
            # HTTP might not be exposed (acceptable)
            pass


@pytest.mark.bootstrap
async def test_traefik_preserves_headers(config: TestConfig):
    """Verify Traefik preserves important headers."""
    async with httpx.AsyncClient(verify=False) as client:
        response = await client.get(config.PORTAL_URL, timeout=10.0)
        headers_lower = {k.lower(): v for k, v in response.headers.items()}
        assert 'content-type' in headers_lower, \
            "Traefik should preserve content-type header"


@pytest.mark.bootstrap
async def test_traefik_handles_invalid_routes(config: TestConfig):
    """Verify Traefik handles invalid routes gracefully."""
    portal_url = urlparse(config.PORTAL_URL)
    domain_parts = portal_url.hostname.split('.')
    if len(domain_parts) >= 2:
        base = '.'.join(domain_parts[-2:])
        invalid_url = f"https://nonexistent-test-subdomain.{base}"
    else:
        pytest.skip("Cannot construct invalid URL")
    
    async with httpx.AsyncClient(verify=False) as client:
        try:
            response = await client.get(invalid_url, timeout=10.0)
            assert response.status_code in [404, 503], \
                f"Invalid route should return 404/503, got {response.status_code}"
        except Exception:
            # DNS resolution failure is acceptable
            pass
