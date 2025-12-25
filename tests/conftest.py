"""
Pytest configuration and fixtures for infrastructure tests.

Precondition checks for CI environment.
"""

import pytest
import os

# Required environment variables for CI/CD
REQUIRED_ENV_VARS = [
    "GITHUB_TOKEN",
    "GITHUB_REPOSITORY",
]


@pytest.fixture(scope="session", autouse=True)
def check_ci_environment():
    """
    PRECONDITION: Validate CI environment before any tests run.
    Fails fast if environment is misconfigured.
    """
    if os.getenv("CI") == "true":
        missing = [var for var in REQUIRED_ENV_VARS if not os.getenv(var)]
        if missing:
            pytest.exit(
                f"❌ PRECONDITION FAILED: Missing required environment variables: {', '.join(missing)}",
                returncode=1
            )
