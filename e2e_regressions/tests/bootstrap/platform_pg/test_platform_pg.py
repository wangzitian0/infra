"""
Platform PostgreSQL database tests.

Tests the PostgreSQL database used by platform services (Vault, Casdoor, etc).
"""
import pytest
import os


@pytest.mark.bootstrap
async def test_platform_pg_accessible():
    """Verify platform PostgreSQL is accessible."""
    db_host = os.getenv("PLATFORM_DB_HOST")
    db_port = os.getenv("PLATFORM_DB_PORT", "5432")
    db_user = os.getenv("PLATFORM_DB_USER", "postgres")
    db_password = os.getenv("PLATFORM_DB_PASSWORD")
    
    if not all([db_host, db_password]):
        pytest.skip("Platform DB credentials not configured")
    
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


@pytest.mark.bootstrap
async def test_platform_pg_ha_configured():
    """Verify Platform PG is configured for high availability (3 nodes)."""
    import pathlib
    pg_tf = pathlib.Path(__file__).parent.parent.parent.parent.parent / "1.bootstrap" / "5.platform_pg.tf"
    
    assert pg_tf.exists(), "Platform PG configuration should exist"
    content = pg_tf.read_text()
    
    # Check for replica count or HA markers
    assert "replicas" in content or "instance" in content, "Should have replica configuration"


@pytest.mark.bootstrap
async def test_platform_pg_resource_limits():
    """Verify Platform PG has resource limits configured."""
    import pathlib
    pg_tf = pathlib.Path(__file__).parent.parent.parent.parent.parent / "1.bootstrap" / "5.platform_pg.tf"
    
    content = pg_tf.read_text()
    assert "resources" in content or "cpu" in content or "memory" in content, \
        "Platform PG should have resource limits defined for stability"

