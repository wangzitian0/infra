# =============================================================================
# ClickHouse User & Database Management for SigNoz
# Purpose: Create dedicated user and databases for SigNoz observability stack
# Architecture:
# - Generate random password in L3
# - Store in Vault at secret/data/signoz
# - Create user in ClickHouse
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
    host     = "clickhouse.data-staging.svc.cluster.local" # Hardcoded for now as per-env pattern
    port     = "9000"
    database = "signoz_traces"
  })
}

# 3. Create SigNoz User
resource "clickhousedbops_user" "signoz" {
  name     = "signoz"
  password = random_password.signoz_clickhouse.result
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
  user      = clickhousedbops_user.signoz.name
  privilege = "ALL"
  database  = clickhousedbops_database.signoz_traces.name
  table     = "*"
}

resource "clickhousedbops_grant_privilege" "signoz_metrics" {
  user      = clickhousedbops_user.signoz.name
  privilege = "ALL"
  database  = clickhousedbops_database.signoz_metrics.name
  table     = "*"
}

resource "clickhousedbops_grant_privilege" "signoz_logs" {
  user      = clickhousedbops_user.signoz.name
  privilege = "ALL"
  database  = clickhousedbops_database.signoz_logs.name
  table     = "*"
}
