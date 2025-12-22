# =============================================================================
# PostgreSQL & ClickHouse User & Database Management for OpenPanel
# Purpose: Create dedicated user and databases for OpenPanel analytics stack
# Layer: L2 Platform (Control Plane / Entitlements)
# Pattern: Follows 51.clickhouse-signoz.tf
# =============================================================================

# =============================================================================
# PostgreSQL Configuration
# =============================================================================

# 1. Generate Password for OpenPanel PostgreSQL user
resource "random_password" "openpanel_postgres" {
  length  = 24
  special = false
}

# 2. Create OpenPanel User in PostgreSQL
resource "postgresql_role" "openpanel" {
  name     = "openpanel"
  login    = true
  password = random_password.openpanel_postgres.result
}

# 3. Create OpenPanel Database (dedicated, not shared with "app")
resource "postgresql_database" "openpanel" {
  name  = "openpanel"
  owner = postgresql_role.openpanel.name
}

# =============================================================================
# ClickHouse Configuration (for event storage)
# =============================================================================

# 4. Generate Password for OpenPanel ClickHouse user
resource "random_password" "openpanel_clickhouse" {
  length  = 24
  special = false
}

# 5. Create OpenPanel User in ClickHouse
# Uses password_sha256_hash_wo (WriteOnly - not stored in state)
resource "clickhousedbops_user" "openpanel" {
  name                            = "openpanel"
  password_sha256_hash_wo         = sha256(random_password.openpanel_clickhouse.result)
  password_sha256_hash_wo_version = 1
}

# 6. Create OpenPanel Events Database in ClickHouse
resource "clickhousedbops_database" "openpanel_events" {
  name = "openpanel_events"
}

# 7. Grant ClickHouse Privileges
# NOTE: Privileges are managed automatically by ClickHouse when user is created.
# The clickhousedbops_grant_privilege resource has a verification bug where
# it fails if privileges already exist (expanded from ALL to individual grants).
# Pattern: Same issue as SigNoz (see 51.clickhouse-signoz.tf)
#
# OpenPanel user already has ALL privileges on openpanel_events database.
# To verify: kubectl exec -n data-staging clickhouse-0 -- clickhouse-client --query "SHOW GRANTS FOR openpanel"

# =============================================================================
# Vault KV Storage
# Store credentials for L4 to consume
# =============================================================================

resource "vault_kv_secret_v2" "openpanel" {
  mount               = vault_mount.kv.path
  name                = "openpanel"
  delete_all_versions = true

  data_json = jsonencode({
    # PostgreSQL (primary database)
    postgres_host     = "postgresql.data-staging.svc.cluster.local"
    postgres_port     = "5432"
    postgres_user     = "openpanel"
    postgres_password = random_password.openpanel_postgres.result
    postgres_database = "openpanel"

    # Redis (cache/queue) - shared L3 instance
    redis_host     = "redis-master.data-staging.svc.cluster.local"
    redis_port     = "6379"
    redis_password = random_password.l3_redis.result

    # ClickHouse (event storage)
    clickhouse_host     = "clickhouse.data-staging.svc.cluster.local"
    clickhouse_port     = "9000"
    clickhouse_user     = "openpanel"
    clickhouse_password = random_password.openpanel_clickhouse.result
    clickhouse_database = "openpanel_events"

    # SSO Configuration
    # OpenPanel does not support native OIDC or SAML.
    # Authentication will be handled by Portal Gate (OAuth2-Proxy).
    # See: docs/ssot/platform.auth.md for authentication architecture.
  })
}
