# =============================================================================
# PostgreSQL & ClickHouse User & Database Management for PostHog
# Purpose: Create dedicated user and databases for PostHog analytics stack
# Layer: L2 Platform (Control Plane / Entitlements)
# Pattern: Follows 51.clickhouse-signoz.tf
# =============================================================================

# =============================================================================
# PostgreSQL Configuration
# =============================================================================

# 1. Generate Password for PostHog PostgreSQL user
resource "random_password" "posthog_postgres" {
  length  = 24
  special = false
}

# 2. Create PostHog User in PostgreSQL
resource "postgresql_role" "posthog" {
  name     = "posthog"
  login    = true
  password = random_password.posthog_postgres.result
}

# 3. Create PostHog Database (dedicated, not shared with "app")
resource "postgresql_database" "posthog" {
  name  = "posthog"
  owner = postgresql_role.posthog.name
}

# =============================================================================
# ClickHouse Configuration (for event storage)
# =============================================================================

# 4. Generate Password for PostHog ClickHouse user
resource "random_password" "posthog_clickhouse" {
  length  = 24
  special = false
}

# 5. Create PostHog User in ClickHouse
# Uses password_sha256_hash_wo (WriteOnly - not stored in state)
resource "clickhousedbops_user" "posthog" {
  name                            = "posthog"
  password_sha256_hash_wo         = sha256(random_password.posthog_clickhouse.result)
  password_sha256_hash_wo_version = 1
}

# 6. Create PostHog Events Database in ClickHouse
resource "clickhousedbops_database" "posthog_events" {
  name = "posthog_events"
}

# 7. Grant ClickHouse Privileges
resource "clickhousedbops_grant_privilege" "posthog_events" {
  grantee_user_name = clickhousedbops_user.posthog.name
  privilege_name    = "ALL"
  database_name     = clickhousedbops_database.posthog_events.name
  table_name        = null # All tables
}

# =============================================================================
# Vault KV Storage
# Store credentials for L4 to consume
# =============================================================================

resource "vault_kv_secret_v2" "posthog" {
  mount               = vault_mount.kv.path
  name                = "posthog"
  delete_all_versions = true

  data_json = jsonencode({
    # PostgreSQL (primary database)
    postgres_host     = "postgresql.data-staging.svc.cluster.local"
    postgres_port     = "5432"
    postgres_user     = "posthog"
    postgres_password = random_password.posthog_postgres.result
    postgres_database = "posthog"

    # Redis (cache/queue) - shared L3 instance
    redis_host     = "redis-master.data-staging.svc.cluster.local"
    redis_port     = "6379"
    redis_password = random_password.l3_redis.result

    # ClickHouse (event storage)
    clickhouse_host     = "clickhouse.data-staging.svc.cluster.local"
    clickhouse_port     = "9000"
    clickhouse_user     = "posthog"
    clickhouse_password = random_password.posthog_clickhouse.result
    clickhouse_database = "posthog_events"

    # SAML SSO Configuration (Casdoor as IdP)
    # These will be populated automatically from Casdoor SAML metadata endpoint
    # URL: https://sso.${internal_domain}/api/saml/metadata?application=built-in/posthog-saml
    saml_idp_entity_id  = "https://sso.${local.internal_domain}"
    saml_idp_sso_url    = "https://sso.${local.internal_domain}/api/saml"
    saml_idp_metadata   = "https://sso.${local.internal_domain}/api/saml/metadata?application=built-in/posthog-saml"
  })
}
