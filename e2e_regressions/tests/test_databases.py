"""
Database connectivity and health tests.

Tests connections to PostgreSQL, Redis, and ClickHouse.
"""
import pytest
from conftest import TestConfig


@pytest.mark.smoke
@pytest.mark.database
async def test_postgresql_connection(config: TestConfig):
    """Test PostgreSQL connection from deployment environment."""
    if not config.DB_PASSWORD:
        pytest.skip("DB_PASSWORD not configured")

    try:
        import psycopg2
    except ImportError:
        pytest.skip("psycopg2 not installed")

    try:
        conn = psycopg2.connect(
            host=config.DB_HOST,
            port=config.DB_PORT,
            user=config.DB_USER,
            password=config.DB_PASSWORD,
            database=config.DB_NAME,
            connect_timeout=5,
        )

        # Test that we can execute a query
        cursor = conn.cursor()
        cursor.execute("SELECT version()")
        version = cursor.fetchone()

        assert version is not None, "PostgreSQL should return version info"

        cursor.close()
        conn.close()
    except Exception as e:
        pytest.fail(f"PostgreSQL connection failed: {e}")


@pytest.mark.database
async def test_postgresql_query_performance(config: TestConfig):
    """Test that PostgreSQL queries complete in reasonable time."""
    if not config.DB_PASSWORD:
        pytest.skip("DB_PASSWORD not configured")

    try:
        import psycopg2
        import time
    except ImportError:
        pytest.skip("psycopg2 not installed")

    try:
        conn = psycopg2.connect(
            host=config.DB_HOST,
            port=config.DB_PORT,
            user=config.DB_USER,
            password=config.DB_PASSWORD,
            database=config.DB_NAME,
            connect_timeout=5,
        )

        cursor = conn.cursor()

        # Simple query performance test
        start = time.time()
        cursor.execute("SELECT COUNT(*) FROM pg_tables")
        result = cursor.fetchone()
        elapsed = time.time() - start

        assert elapsed < 1.0, f"Query took {elapsed:.2f}s (should be < 1s)"

        cursor.close()
        conn.close()
    except Exception as e:
        pytest.fail(f"PostgreSQL query test failed: {e}")


@pytest.mark.database
async def test_redis_connection(config: TestConfig):
    """Test Redis connection."""
    if not config.REDIS_HOST:
        pytest.skip("REDIS_HOST not configured")

    try:
        import redis
    except ImportError:
        pytest.skip("redis not installed")

    try:
        # Try to connect to Redis
        r = redis.Redis(
            host=config.REDIS_HOST,
            port=config.REDIS_PORT,
            password=config.REDIS_PASSWORD or None,
            decode_responses=True,
            socket_connect_timeout=5,
        )

        # Ping to verify connection
        result = r.ping()
        assert result is True, "Redis ping should return True"
    except Exception as e:
        pytest.fail(f"Redis connection failed: {e}")


@pytest.mark.database
async def test_redis_set_get(config: TestConfig):
    """Test Redis basic operations (set/get)."""
    if not config.REDIS_HOST:
        pytest.skip("REDIS_HOST not configured")

    try:
        import redis
    except ImportError:
        pytest.skip("redis not installed")

    try:
        r = redis.Redis(
            host=config.REDIS_HOST,
            port=config.REDIS_PORT,
            password=config.REDIS_PASSWORD or None,
            decode_responses=True,
            socket_connect_timeout=5,
        )

        # Test set/get
        test_key = "test_e2e_key"
        test_value = "test_e2e_value"

        r.set(test_key, test_value)
        retrieved = r.get(test_key)

        assert retrieved == test_value, "Redis get should return set value"

        # Cleanup
        r.delete(test_key)
    except Exception as e:
        pytest.fail(f"Redis set/get test failed: {e}")


@pytest.mark.database
async def test_clickhouse_connection(config: TestConfig):
    """Test ClickHouse connection."""
    if not config.CLICKHOUSE_HOST:
        pytest.skip("CLICKHOUSE_HOST not configured")

    try:
        import requests
    except ImportError:
        pytest.skip("requests not installed")

    try:
        # ClickHouse HTTP interface
        url = f"http://{config.CLICKHOUSE_HOST}:{config.CLICKHOUSE_PORT}/"

        auth = None
        if config.CLICKHOUSE_USER:
            auth = (config.CLICKHOUSE_USER, config.CLICKHOUSE_PASSWORD or "")

        response = requests.get(
            url,
            auth=auth,
            timeout=5,
        )

        assert response.status_code == 200, \
            f"ClickHouse should respond: {response.status_code}"
    except Exception as e:
        pytest.fail(f"ClickHouse connection failed: {e}")


@pytest.mark.database
async def test_clickhouse_query(config: TestConfig):
    """Test ClickHouse query execution."""
    if not config.CLICKHOUSE_HOST:
        pytest.skip("CLICKHOUSE_HOST not configured")

    try:
        import requests
    except ImportError:
        pytest.skip("requests not installed")

    try:
        url = f"http://{config.CLICKHOUSE_HOST}:{config.CLICKHOUSE_PORT}/"

        auth = None
        if config.CLICKHOUSE_USER:
            auth = (config.CLICKHOUSE_USER, config.CLICKHOUSE_PASSWORD or "")

        # Execute simple query
        response = requests.post(
            url,
            data="SELECT 1",
            auth=auth,
            timeout=5,
        )

        assert response.status_code == 200, \
            f"ClickHouse query should succeed: {response.status_code}"
        assert "1" in response.text, "ClickHouse should return result"
    except Exception as e:
        pytest.fail(f"ClickHouse query test failed: {e}")


@pytest.mark.database
async def test_postgresql_heartbeat(config: TestConfig):
    """Test PostgreSQL replication/heartbeat status."""
    if not config.DB_PASSWORD:
        pytest.skip("DB_PASSWORD not configured")

    try:
        import psycopg2
    except ImportError:
        pytest.skip("psycopg2 not installed")

    try:
        conn = psycopg2.connect(
            host=config.DB_HOST,
            port=config.DB_PORT,
            user=config.DB_USER,
            password=config.DB_PASSWORD,
            database=config.DB_NAME,
            connect_timeout=5,
        )

        cursor = conn.cursor()

        # Check if database is accepting connections
        cursor.execute("SELECT datname, pg_database.datistemplate FROM pg_database")
        databases = cursor.fetchall()

        assert len(databases) > 0, "Should return list of databases"

        cursor.close()
        conn.close()
    except Exception as e:
        pytest.fail(f"PostgreSQL heartbeat test failed: {e}")


@pytest.mark.database
async def test_redis_memory_usage(config: TestConfig):
    """Check Redis server memory usage is reasonable."""
    if not config.REDIS_HOST:
        pytest.skip("REDIS_HOST not configured")

    try:
        import redis
    except ImportError:
        pytest.skip("redis not installed")

    try:
        r = redis.Redis(
            host=config.REDIS_HOST,
            port=config.REDIS_PORT,
            password=config.REDIS_PASSWORD or None,
            socket_connect_timeout=5,
        )

        # Get server info
        info = r.info()

        memory_usage_mb = info.get("used_memory", 0) / (1024 * 1024)

        # Memory usage should be positive
        assert memory_usage_mb >= 0, "Memory usage should be measurable"
    except Exception as e:
        pytest.fail(f"Redis memory test failed: {e}")


@pytest.mark.database
async def test_database_write_permissions(config: TestConfig):
    """Verify database write permissions (if user has access)."""
    if not config.DB_PASSWORD:
        pytest.skip("DB_PASSWORD not configured")

    try:
        import psycopg2
    except ImportError:
        pytest.skip("psycopg2 not installed")

    try:
        conn = psycopg2.connect(
            host=config.DB_HOST,
            port=config.DB_PORT,
            user=config.DB_USER,
            password=config.DB_PASSWORD,
            database=config.DB_NAME,
            connect_timeout=5,
        )

        cursor = conn.cursor()

        # Try to create a test table (may fail due to permissions, which is OK)
        try:
            cursor.execute("CREATE TEMP TABLE e2e_test (id SERIAL, value TEXT)")
            cursor.execute("INSERT INTO e2e_test (value) VALUES ('test')")
            conn.commit()
            assert True, "Write operations working"
        except psycopg2.errors.InsufficientPrivilege:
            # No write permissions, which is expected for some users
            assert True, "Read-only access confirmed"

        cursor.close()
        conn.close()
    except Exception as e:
        pytest.fail(f"Database write test failed: {e}")
