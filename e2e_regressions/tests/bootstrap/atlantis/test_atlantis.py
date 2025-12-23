"""
Atlantis CI/CD service tests.

Tests Atlantis configuration and deployment status.
"""
import pytest
import pathlib


@pytest.mark.bootstrap
async def test_atlantis_config_exists():
    """Verify atlantis.yaml configuration file exists."""
    atlantis_config = pathlib.Path(__file__).parent.parent.parent.parent.parent / "atlantis.yaml"
    assert atlantis_config.exists(), "atlantis.yaml should exist in repo root"


@pytest.mark.bootstrap
async def test_atlantis_config_not_empty():
    """Verify atlantis.yaml has content."""
    atlantis_config = pathlib.Path(__file__).parent.parent.parent.parent.parent / "atlantis.yaml"
    
    if not atlantis_config.exists():
        pytest.skip("atlantis.yaml not found")
    
    content = atlantis_config.read_text()
    assert len(content) > 100, "atlantis.yaml should have substantial content"
    assert "version:" in content or "version :" in content, "Config should specify version"
    assert "projects:" in content or "projects :" in content, "Config should define projects"


