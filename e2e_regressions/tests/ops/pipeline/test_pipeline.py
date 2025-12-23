"""
CI/CD Pipeline tests.

Tests pipeline execution, Atlantis workflows, and deployment processes.

See README.md for SSOT documentation on pipeline configuration.
"""
import pytest


@pytest.mark.ops
async def test_github_workflows_exist():
    """Verify GitHub Actions workflows are present."""
    import pathlib
    workflow_path = pathlib.Path(__file__).parent.parent.parent.parent.parent / ".github" / "workflows"
    
    assert workflow_path.exists(), ".github/workflows directory should exist"
    
    # Check for core infra workflows
    workflows = list(workflow_path.glob("*.yml")) + list(workflow_path.glob("*.yaml"))
    assert len(workflows) > 0, "Should have at least one CI workflow"


@pytest.mark.ops
async def test_atlantis_workflow_config():
    """Verify Atlantis workflow configuration in atlantis.yaml."""
    import pathlib
    atlantis_config = pathlib.Path(__file__).parent.parent.parent.parent.parent / "atlantis.yaml"
    
    if not atlantis_config.exists():
        pytest.skip("atlantis.yaml not found in repo root")
        
    content = atlantis_config.read_text()
    assert "workflows:" in content, "atlantis.yaml should define custom workflows"
    assert "autoplan:" in content or "apply:" in content, "atlantis.yaml should have operation configs"
    assert "projects:" in content, "atlantis.yaml should define projects"

