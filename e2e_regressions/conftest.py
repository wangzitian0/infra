"""
Global pytest fixtures and configuration for E2E tests.
"""
import os
import asyncio
from typing import AsyncGenerator
from pathlib import Path
import pytest
from dotenv import load_dotenv
from playwright.async_api import async_playwright, Browser, BrowserContext, Page


# Load environment variables
env_path = Path(__file__).parent / ".env"
load_dotenv(env_path)

# Try to extract CI secret schema for consistency (read file directly to avoid import issues)
CI_MAPPING = {}
try:
    import re
    infra_root = Path(__file__).parent.parent
    loader_path = infra_root / "tools" / "ci_load_secrets.py"
    if loader_path.exists():
        content = loader_path.read_text()
        # Simple regex to extract MAPPING dict entries (matches "KEY": "VALUE", or 'KEY': 'VALUE')
        mapping_match = re.search(r"MAPPING = \{(.*?)\}", content, re.DOTALL)
        if mapping_match:
            # Handle both single and double quotes for flexibility
            entries = re.findall(r'[\'"]([^\'"]+)[\'"]:\s*[\'"]([^\'"]+)[\'"]', mapping_match.group(1))
            CI_MAPPING = dict(entries)
except Exception:
    # Silent fail, fallback to defaults in TestConfig
    pass


def get_env_required(name: str) -> str:
    """Get environment variable or raise error."""
    val = os.getenv(name)
    if not val:
        raise RuntimeError(f"Required environment variable '{name}' is not set. Check your CI/local .env file.")
    return val


class TestConfig:
    """Test configuration from environment variables."""

    # Domains (Required)
    BASE_DOMAIN = get_env_required("BASE_DOMAIN")
    INTERNAL_DOMAIN = os.getenv("INTERNAL_DOMAIN", BASE_DOMAIN)

    # Portal & SSO (Strictly derived or overridden)
    PORTAL_URL = os.getenv("PORTAL_URL", f"https://home.{INTERNAL_DOMAIN}")
    SSO_URL = os.getenv("SSO_URL", f"https://sso.{INTERNAL_DOMAIN}")
    
    # Credentials (Use names defined in ci_load_secrets schema if possible)
    _user_var = CI_MAPPING.get("E2E_TEST_USERNAME", "E2E_TEST_USERNAME")
    _pass_var = CI_MAPPING.get("E2E_TEST_PASSWORD", "E2E_TEST_PASSWORD")
    
    E2E_TEST_USERNAME = os.getenv(_user_var, "admin")
    E2E_TEST_PASSWORD = get_env_required(_pass_var)

    # Platform Services (Strictly derived or overridden)
    VAULT_URL = os.getenv("VAULT_URL", f"https://secrets.{INTERNAL_DOMAIN}")
    DASHBOARD_URL = os.getenv("DASHBOARD_URL", f"https://kdashboard.{INTERNAL_DOMAIN}")
    DIGGER_URL = os.getenv("DIGGER_URL", f"https://digger.{INTERNAL_DOMAIN}")
    KUBERO_URL = os.getenv("KUBERO_URL", f"https://kcloud.{INTERNAL_DOMAIN}")
    SIGNOZ_URL = os.getenv("SIGNOZ_URL", f"https://signoz.{INTERNAL_DOMAIN}")
    K3S_URL = os.getenv("K3S_URL", f"https://k3s.{INTERNAL_DOMAIN}:6443")

    # K8s Resource Identifiers
    class K8sResources:
        PLATFORM_PG_NAME = "platform-pg"
        CNPG_CLUSTER_TYPE = "clusters.postgresql.cnpg.io"

    # Test Configuration (Sensible defaults for execution)
    HEADLESS = os.getenv("HEADLESS", "true").lower() == "true"
    TIMEOUT_MS = int(os.getenv("TIMEOUT_MS", "30000"))
    SLOW_MO = int(os.getenv("SLOW_MO", "0"))


@pytest.fixture(scope="session")
def config() -> TestConfig:
    """Provide test configuration."""
    return TestConfig()


@pytest.fixture(scope="session")
def event_loop():
    """Create and set event loop for async tests."""
    loop = asyncio.new_event_loop()
    yield loop
    loop.close()


@pytest.fixture
async def browser() -> AsyncGenerator[Browser, None]:
    """Launch Playwright browser."""
    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=TestConfig.HEADLESS,
            slow_mo=TestConfig.SLOW_MO,
        )
        yield browser
        await browser.close()


@pytest.fixture
async def context(browser: Browser) -> AsyncGenerator[BrowserContext, None]:
    """Create browser context."""
    context = await browser.new_context(
        ignore_https_errors=True,  # Allow self-signed certs
        viewport={"width": 1280, "height": 720},
    )
    yield context
    await context.close()


@pytest.fixture
async def page(context: BrowserContext) -> AsyncGenerator[Page, None]:
    """Create browser page."""
    page = await context.new_page()
    page.set_default_timeout(TestConfig.TIMEOUT_MS)
    yield page
    await page.close()


# Markers
def pytest_configure(config):
    """Register custom markers."""
    config.addinivalue_line("markers", "smoke: quick smoke tests")
    config.addinivalue_line("markers", "sso: SSO/Portal tests")
    config.addinivalue_line("markers", "platform: Platform service tests")
    config.addinivalue_line("markers", "api: API endpoint tests")
    config.addinivalue_line("markers", "e2e: full end-to-end tests")
