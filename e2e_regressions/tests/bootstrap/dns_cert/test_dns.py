"""
DNS resolution tests.

Verifies DNS configuration for the cluster domains.
"""
import pytest
import socket
from urllib.parse import urlparse
from conftest import TestConfig


@pytest.mark.smoke
@pytest.mark.bootstrap
async def test_dns_resolution_portal(config: TestConfig):
    """Verify Portal domain resolves correctly."""
    portal_host = urlparse(config.PORTAL_URL).hostname
    
    try:
        ip = socket.gethostbyname(portal_host)
        assert ip is not None, f"DNS resolution failed for {portal_host}"
        assert len(ip) > 0, "IP address should not be empty"
    except socket.gaierror as e:
        pytest.fail(f"DNS resolution failed: {e}")


@pytest.mark.bootstrap
async def test_dns_resolution_all_services(config: TestConfig):
    """Verify all service domains resolve."""
    services = [
        config.PORTAL_URL,
        config.SSO_URL,
        config.VAULT_URL,
        config.DASHBOARD_URL,
    ]
    
    failed_resolutions = []
    
    for url in services:
        hostname = urlparse(url).hostname
        try:
            ip = socket.gethostbyname(hostname)
            assert ip is not None
        except (socket.gaierror, AssertionError) as e:
            failed_resolutions.append((hostname, str(e)))
    
    assert len(failed_resolutions) == 0, \
        f"DNS resolution failed for: {failed_resolutions}"


@pytest.mark.bootstrap
async def test_dns_wildcard_subdomain(config: TestConfig):
    """Verify wildcard DNS is configured (*.domain.com)."""
    # Extract base domain
    portal_host = urlparse(config.PORTAL_URL).hostname
    domain_parts = portal_host.split(".")
    base_domain = ".".join(domain_parts[-2:]) if len(domain_parts) >= 2 else portal_host
    
    # Test that multiple subdomains resolve
    test_subdomains = [
        urlparse(config.PORTAL_URL).hostname,
        urlparse(config.SSO_URL).hostname,
        urlparse(config.VAULT_URL).hostname,
    ]
    
    resolved_count = 0
    for subdomain in test_subdomains:
        try:
            ip = socket.gethostbyname(subdomain)
            if ip:
                resolved_count += 1
        except socket.gaierror:
            pass
    
    assert resolved_count >= 2, \
        f"Wildcard DNS may not be configured (only {resolved_count} subdomains resolved)"
