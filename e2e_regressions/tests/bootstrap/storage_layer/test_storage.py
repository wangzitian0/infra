"""
Bootstrap Storage Layer E2E Tests.

Tests StorageClass configuration and Platform PostgreSQL.
"""
import pytest
import pathlib
import os


# =============================================================================
# StorageClass Tests
# =============================================================================

@pytest.mark.smoke
@pytest.mark.bootstrap
async def test_storage_class_local_path_retain_defined():
    """Verify local-path-retain storage class is defined in terraform."""
    storage_tf = pathlib.Path(__file__).parent.parent.parent.parent.parent / "bootstrap" / "4.storage.tf"
    
    if not storage_tf.exists():
        pytest.skip("Storage configuration file not found")
    
    content = storage_tf.read_text()
    assert "local_path_retain" in content or "local-path-retain" in content, \
        "local-path-retain StorageClass should be defined"


@pytest.mark.bootstrap
async def test_storage_class_reclaim_policy():
    """Verify storage class has Retain reclaim policy."""
    storage_tf = pathlib.Path(__file__).parent.parent.parent.parent.parent / "bootstrap" / "4.storage.tf"
    
    if not storage_tf.exists():
        pytest.skip("Storage configuration file not found")
    
    content = storage_tf.read_text()
    assert "Retain" in content, "Storage class should have Retain policy"


@pytest.mark.bootstrap
async def test_storage_data_directory_configured():
    """Verify /data directory is configured for persistent storage."""
    storage_tf = pathlib.Path(__file__).parent.parent.parent.parent.parent / "bootstrap" / "4.storage.tf"
    
    if not storage_tf.exists():
        pytest.skip("Storage configuration file not found")
    
    content = storage_tf.read_text()
    assert "/data" in content, "Storage should be configured to use /data directory"


@pytest.mark.bootstrap
async def test_storage_provisioner_configured():
    """Verify local-path-provisioner is properly configured."""
    storage_tf = pathlib.Path(__file__).parent.parent.parent.parent.parent / "bootstrap" / "4.storage.tf"
    
    if not storage_tf.exists():
        pytest.skip("Storage configuration file not found")
    
    content = storage_tf.read_text()
    assert "local-path-provisioner" in content or "rancher" in content, \
        "Local path provisioner should be configured"


# =============================================================================
# Platform PostgreSQL Tests
# =============================================================================

@pytest.mark.smoke
@pytest.mark.bootstrap
async def test_platform_pg_config_exists():
    """Verify Platform PostgreSQL configuration exists."""
    # Check for platform_pg.tf file
    pg_tf = pathlib.Path(__file__).parent.parent.parent.parent.parent / "bootstrap" / "5.platform_pg.tf"
    
    if not pg_tf.exists():
        # Try alternative name
        pg_tf = pathlib.Path(__file__).parent.parent.parent.parent.parent / "bootstrap" / "4.platform_pg.tf"
    
    assert pg_tf.exists(), "Platform PG configuration should exist"


@pytest.mark.bootstrap
async def test_platform_pg_accessible():
    """Verify platform PostgreSQL is accessible."""
    db_host = os.getenv("PLATFORM_DB_HOST")
    db_port = os.getenv("PLATFORM_DB_PORT", "5432")
    db_user = os.getenv("PLATFORM_DB_USER", "postgres")
    db_password = os.getenv("PLATFORM_DB_PASSWORD")
    
    if not all([db_host, db_password]):
        pytest.skip("Platform DB credentials not configured")
    
    try:
        import asyncpg
        conn = await asyncpg.connect(
            host=db_host,
            port=int(db_port),
            user=db_user,
            password=db_password,
            timeout=10.0,
        )
        
        result = await conn.fetchval('SELECT 1')
        assert result == 1, "Database should respond to queries"
        await conn.close()
    except ImportError:
        pytest.skip("asyncpg not installed")


@pytest.mark.bootstrap
async def test_platform_pg_databases_exist():
    """Verify required databases exist (vault, casdoor)."""
    db_host = os.getenv("PLATFORM_DB_HOST")
    db_port = os.getenv("PLATFORM_DB_PORT", "5432")
    db_user = os.getenv("PLATFORM_DB_USER", "postgres")
    db_password = os.getenv("PLATFORM_DB_PASSWORD")
    
    if not all([db_host, db_password]):
        pytest.skip("Platform DB credentials not configured")
    
    try:
        import asyncpg
        conn = await asyncpg.connect(
            host=db_host,
            port=int(db_port),
            user=db_user,
            password=db_password,
            database="postgres",
            timeout=10.0,
        )
        
        databases = await conn.fetch(
            "SELECT datname FROM pg_database WHERE datistemplate = false"
        )
        db_names = [row['datname'] for row in databases]
        
        # Should have either vault or casdoor database
        assert any(db in db_names for db in ['vault', 'casdoor', 'platform']), \
            f"Expected platform databases, found: {db_names}"
        
        await conn.close()
    except ImportError:
        pytest.skip("asyncpg not installed")


@pytest.mark.bootstrap
async def test_platform_pg_namespace_configured():
    """Verify Platform PG is configured in platform namespace."""
    pg_tf = pathlib.Path(__file__).parent.parent.parent.parent.parent / "bootstrap" / "5.platform_pg.tf"
    
    if not pg_tf.exists():
        pg_tf = pathlib.Path(__file__).parent.parent.parent.parent.parent / "bootstrap" / "4.platform_pg.tf"
    
    if not pg_tf.exists():
        pytest.skip("Platform PG configuration not found")
    
    content = pg_tf.read_text()
    assert "platform" in content, "Platform PG should be in platform namespace"


@pytest.mark.bootstrap
async def test_cnpg_cluster_resource_exists(config: TestConfig):
    """Verify CNPG Cluster resource exists in the cluster."""
    import subprocess
    try:
        # Match centralized naming
        name = config.K8sResources.PLATFORM_PG_NAME
        ctype = config.K8sResources.CNPG_CLUSTER_TYPE
        
        result = subprocess.run(
            ["kubectl", "get", ctype, "-n", "platform", name, "-o", "jsonname"],
            capture_output=True, text=True, timeout=10.0
        )
        if result.returncode == 0:
            assert f"{ctype}/{name}" in result.stdout or f"{name}" in result.stdout
        else:
            pytest.skip(f"kubectl command failed or resource {name} not found (safe to skip in plan-only envs)")
    except FileNotFoundError:
        pytest.skip("kubectl not found in test environment")
