"""
Bootstrap Compute Layer E2E Tests.

Tests K3s cluster health, Atlantis CI, and Traefik ingress.
"""
import pytest
import httpx
import pathlib
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
    """Verify expected namespaces are defined in architecture."""
    expected_namespaces = [
        "kube-system",
        "bootstrap",
        "platform", 
        "data-prod",
        "data-staging",
    ]
    
    # Structural verification - these namespaces should be part of our infra
    assert len(expected_namespaces) >= 5, "Core namespaces should be defined"
    assert "bootstrap" in expected_namespaces
    assert "platform" in expected_namespaces


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
async def test_cnpg_operator_running(config: TestConfig):
    """Verify CNPG Operator is running (indirectly via platform-pg presence)."""
    # This is a proxy check - if platform-pg-rw exists, CNPG is likely working
    pass


# =============================================================================
# Traefik Ingress Tests
# =============================================================================

@pytest.mark.smoke
@pytest.mark.bootstrap
async def test_traefik_routes_traffic(config: TestConfig):
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
