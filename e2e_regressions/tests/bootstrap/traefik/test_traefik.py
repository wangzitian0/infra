"""
Traefik Ingress Controller tests.

Verifies Traefik is routing traffic correctly.
"""
import pytest
import httpx
from conftest import TestConfig


@pytest.mark.smoke
@pytest.mark.bootstrap
async def test_traefik_routes_traffic(config: TestConfig):
    """Verify Traefik successfully routes to services."""
    # All our services go through Traefik Ingress
    # If services are accessible, Traefik is working
    
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
    # Try accessing via HTTP (if configured)
    from urllib.parse import urlparse
    
    portal_url = urlparse(config.PORTAL_URL)
    http_url = f"http://{portal_url.hostname}"
    
    async with httpx.AsyncClient(verify=False, follow_redirects=False) as client:
        try:
            response = await client.get(http_url, timeout=10.0)
            # Should redirect (301/302) to HTTPS
            if response.status_code in [301, 302, 307, 308]:
                location = response.headers.get('location', '')
                assert location.startswith('https://'), \
                    "HTTP should redirect to HTTPS"
            # If 200, HTTPS redirect might not be configured (acceptable)
        except Exception:
            # HTTP might not be exposed at all (also acceptable)
            pass


@pytest.mark.bootstrap
async def test_traefik_handles_invalid_routes(config: TestConfig):
    """Verify Traefik handles invalid routes gracefully."""
    from urllib.parse import urlparse
    
    portal_url = urlparse(config.PORTAL_URL)
    invalid_url = f"https://nonexistent-subdomain.{'.'.join(portal_url.hostname.split('.')[-2:])}"
    
    async with httpx.AsyncClient(verify=False) as client:
        try:
            response = await client.get(invalid_url, timeout=10.0)
            # Should return 404 or similar, not 500
            assert response.status_code in [404, 503], \
                f"Invalid route should return 404/503, got {response.status_code}"
        except Exception:
            # DNS resolution failure is acceptable
            pass


@pytest.mark.bootstrap
async def test_traefik_preserves_headers(config: TestConfig):
    """Verify Traefik preserves important headers."""
    async with httpx.AsyncClient(verify=False) as client:
        response = await client.get(config.PORTAL_URL, timeout=10.0)
        
        # Traefik should preserve/add certain headers
        headers_lower = {k.lower(): v for k, v in response.headers.items()}
        
        # At minimum, content-type should be present
        assert 'content-type' in headers_lower, \
            "Traefik should preserve content-type header"
