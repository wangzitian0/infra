"""
Storage and PVC tests.

Verifies persistent storage is working correctly.
"""
import pytest


@pytest.mark.bootstrap
async def test_storage_class_defined():
    """Verify local-path-retain storage class is defined in terraform."""
    import pathlib
    storage_tf = pathlib.Path(__file__).parent.parent.parent.parent.parent / "1.bootstrap" / "4.storage.tf"
    
    assert storage_tf.exists(), "Storage configuration should exist"
    content = storage_tf.read_text()
    
    assert "resource \"kubernetes_storage_class\" \"local_path_retain\"" in content
    assert "reclaim_policy         = \"Retain\"" in content


@pytest.mark.bootstrap
async def test_storage_config_map_patched():
    """Verify local-path-provisioner configuration map is patched."""
    import pathlib
    storage_tf = pathlib.Path(__file__).parent.parent.parent.parent.parent / "1.bootstrap" / "4.storage.tf"
    
    content = storage_tf.read_text()
    assert "resource \"kubernetes_config_map_v1\" \"local_path_config\"" in content
    assert "/data/local-path-provisioner" in content, "Storage should be configured to use /data"

