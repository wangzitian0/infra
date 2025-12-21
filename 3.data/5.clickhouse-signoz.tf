# =============================================================================
# ClickHouse User & Database Management for SigNoz
# Purpose: Create dedicated user and databases for SigNoz observability stack
# Architecture:
# - Generate random password in L3
# - Store in Vault at secret/data/signoz
# - Create user in ClickHouse via clickhousedbops provider
# 
# Note: Requires TF 1.11+ for password_sha256_hash_wo (WriteOnly attribute)
# =============================================================================

# 1. Generate Password
resource "random_password" "signoz_clickhouse" {
  length  = 24
  special = false
}

# 2. Store in Vault (L3 writes to L2's Vault KV mount)
resource "vault_kv_secret_v2" "signoz_clickhouse" {
  mount               = data.terraform_remote_state.l2_platform.outputs.vault_kv_mount
  name                = "signoz"
  delete_all_versions = true

  data_json = jsonencode({
    username = "signoz"
    password = random_password.signoz_clickhouse.result
    host     = "clickhouse.${local.namespace_name}.svc.cluster.local"
    port     = "9000"
    database = "signoz_traces"
  })
}

# 3. Create SigNoz User
# Uses password_sha256_hash_wo (WriteOnly - not stored in state)
resource "clickhousedbops_user" "signoz" {
  name                            = "signoz"
  password_sha256_hash_wo         = sha256(random_password.signoz_clickhouse.result)
  password_sha256_hash_wo_version = 1
}

# Create SigNoz Databases
resource "clickhousedbops_database" "signoz_traces" {
  name = "signoz_traces"
}

resource "clickhousedbops_database" "signoz_metrics" {
  name = "signoz_metrics"
}

resource "clickhousedbops_database" "signoz_logs" {
  name = "signoz_logs"
}

# Grant Privileges
# signoz user needs ALL on signoz_* databases
resource "clickhousedbops_grant_privilege" "signoz_traces" {
  grantee_user_name = clickhousedbops_user.signoz.name
  privilege_name    = "ALL"
  database_name     = clickhousedbops_database.signoz_traces.name
  table_name        = null # All tables
}

resource "clickhousedbops_grant_privilege" "signoz_metrics" {
  grantee_user_name = clickhousedbops_user.signoz.name
  privilege_name    = "ALL"
  database_name     = clickhousedbops_database.signoz_metrics.name
  table_name        = null # All tables
}

resource "clickhousedbops_grant_privilege" "signoz_logs" {
  grantee_user_name = clickhousedbops_user.signoz.name
  privilege_name    = "ALL"
  database_name     = clickhousedbops_database.signoz_logs.name
  table_name        = null # All tables
}
