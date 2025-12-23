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


class TestConfig:
    """Test configuration from environment variables."""

    # Portal & SSO
    PORTAL_URL = os.getenv("PORTAL_URL", "https://home.zitian.party")
    SSO_URL = os.getenv("SSO_URL", "https://sso.zitian.party")
    TEST_USERNAME = os.getenv("TEST_USERNAME", "admin")
    TEST_PASSWORD = os.getenv("TEST_PASSWORD", "")

    # Platform Services
    VAULT_URL = os.getenv("VAULT_URL", "https://secrets.zitian.party")
    DASHBOARD_URL = os.getenv("DASHBOARD_URL", "https://kdashboard.zitian.party")

    # Test Configuration
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
