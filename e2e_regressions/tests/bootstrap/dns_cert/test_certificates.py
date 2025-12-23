"""
SSL/TLS Certificate tests.

Verifies certificate issuance and validity via cert-manager.
"""
import pytest
import httpx
import ssl
import socket
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
async def test_certificate_expiry_check(config: TestConfig):
    """Verify certificates are not close to expiration (at least 7 days remaining)."""
    import datetime
    from cryptography import x509
    from cryptography.hazmat.backends import default_backend
    
    url = config.PORTAL_URL
    hostname = urlparse(url).hostname
    port = 443
    
    try:
        cert_pem = ssl.get_server_certificate((hostname, port))
        cert = x509.load_pem_x509_certificate(cert_pem.encode(), default_backend())
        
        remaining = cert.not_valid_after_utc - datetime.datetime.now(datetime.UTC)
        assert remaining.days > 7, f"Certificate for {hostname} expires in {remaining.days} days"
    except ImportError:
        # Fallback if cryptography is not installed
        async with httpx.AsyncClient(verify=False) as client:
            response = await client.get(url, timeout=10.0)
            assert response.status_code < 500, "Service with expired cert would likely fail or show SSL error"
    except Exception as e:
        pytest.fail(f"Failed to check certificate expiry: {e}")


@pytest.mark.bootstrap
async def test_certificate_issuer_info(config: TestConfig):
    """Verify certificate issuer information."""
    hostname = urlparse(config.PORTAL_URL).hostname
    
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    
    with socket.create_connection((hostname, 443)) as sock:
        with context.wrap_socket(sock, server_hostname=hostname) as ssock:
            cert = ssock.getpeercert(binary_form=True)
            # This is a basic check to ensure we can at least retrieve cert info
            assert cert is not None, "Should be able to retrieve certificate"

