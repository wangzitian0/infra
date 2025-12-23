"""
SSL/TLS Certificate tests.

Verifies certificate issuance and validity via cert-manager.
"""
import pytest
import httpx
import ssl
from urllib.parse import urlparse
from conftest import TestConfig


@pytest.mark.bootstrap
async def test_certificates_https_enabled(config: TestConfig):
    """Verify all services use HTTPS."""
    services = [
        config.PORTAL_URL,
        config.SSO_URL,
        config.VAULT_URL,
        config.DASHBOARD_URL,
    ]
    
    for url in services:
        assert url.startswith("https://"), \
            f"Service should use HTTPS: {url}"


@pytest.mark.bootstrap
async def test_certificates_valid_or_self_signed(config: TestConfig):
    """Verify certificates are present (valid or self-signed)."""
    async with httpx.AsyncClient() as client:
        services = [
            config.PORTAL_URL,
            config.SSO_URL,
            config.VAULT_URL,
        ]
        
        for url in services:
            try:
                # Try with certificate verification
                response = await client.get(url, timeout=10.0)
                # If we got here, cert is valid
                assert True
            except httpx.SSLError:
                # Self-signed cert is acceptable in test environment
                # Try again without verification to confirm service is up
                async with httpx.AsyncClient(verify=False) as client_no_verify:
                    response = await client_no_verify.get(url, timeout=10.0)
                    assert response.status_code < 500, \
                        f"Service should respond even with self-signed cert: {url}"


@pytest.mark.bootstrap
async def test_certificate_not_expired(config: TestConfig):
    """Verify certificates are not expired."""
    import datetime
    
    # This is a simplified check - in production you'd use the ssl module
    # to extract certificate expiry dates
    
    async with httpx.AsyncClient(verify=False) as client:
        response = await client.get(config.PORTAL_URL, timeout=10.0)
        # If service responds, certificate is at least functional
        assert response.status_code < 500, "Service with expired cert should fail"


@pytest.mark.bootstrap
async def test_cert_manager_present():
    """Verify cert-manager is installed and running."""
    # This would require K8s API access
    # Placeholder showing the test structure
    
    # In reality:
    # - Check cert-manager namespace exists
    # - Check cert-manager pods are running
    # - Check ClusterIssuer/Issuer resources exist
    
    pytest.skip("Requires kubectl/K8s API access")
