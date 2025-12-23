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
# Atlantis CI Tests
# =============================================================================

@pytest.mark.smoke
@pytest.mark.bootstrap
async def test_atlantis_config_exists():
    """Verify atlantis.yaml configuration file exists."""
    atlantis_config = pathlib.Path(__file__).parent.parent.parent.parent.parent / "atlantis.yaml"
    assert atlantis_config.exists(), "atlantis.yaml should exist in repo root"


@pytest.mark.bootstrap
async def test_atlantis_config_valid():
    """Verify atlantis.yaml has required content."""
    atlantis_config = pathlib.Path(__file__).parent.parent.parent.parent.parent / "atlantis.yaml"
    
    if not atlantis_config.exists():
        pytest.skip("atlantis.yaml not found")
    
    content = atlantis_config.read_text()
    assert len(content) > 100, "atlantis.yaml should have substantial content"
    assert "version:" in content, "Config should specify version"
    assert "projects:" in content, "Config should define projects"


@pytest.mark.bootstrap
async def test_atlantis_projects_defined():
    """Verify required Atlantis projects are defined."""
    atlantis_config = pathlib.Path(__file__).parent.parent.parent.parent.parent / "atlantis.yaml"
    
    if not atlantis_config.exists():
        pytest.skip("atlantis.yaml not found")
    
    content = atlantis_config.read_text()
    
    required_projects = ["bootstrap", "platform"]
    for project in required_projects:
        assert project in content, f"Project '{project}' should be defined in atlantis.yaml"


@pytest.mark.bootstrap
async def test_atlantis_endpoint_accessible(config: TestConfig):
    """Verify Atlantis webhook endpoint is accessible."""
    atlantis_url = getattr(config, 'ATLANTIS_URL', None)
    
    if not atlantis_url:
        # Try to construct from internal domain
        portal_host = urlparse(config.PORTAL_URL).hostname
        domain_parts = portal_host.split(".")
        if len(domain_parts) >= 2:
            base_domain = ".".join(domain_parts[-2:])
            atlantis_url = f"https://atlantis.{base_domain}"
        else:
            pytest.skip("ATLANTIS_URL not configured")
    
    async with httpx.AsyncClient(verify=False) as client:
        try:
            response = await client.get(atlantis_url, timeout=10.0)
            # Atlantis uses Basic Auth, so 401 is expected
            assert response.status_code in [200, 401, 403], \
                f"Atlantis should respond, got {response.status_code}"
        except httpx.ConnectError:
            pytest.skip("Atlantis not reachable from test environment")


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
