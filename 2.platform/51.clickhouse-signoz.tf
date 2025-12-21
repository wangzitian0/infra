# =============================================================================
# ClickHouse User & Database Management for SigNoz
# Purpose: Create dedicated user and databases for SigNoz observability stack
# Layer: L2 Platform (Control Plane / Entitlements)
# =============================================================================

# Declarative imports to adopt existing resources (idempotency)
import {
  to = clickhousedbops_user.signoz
  id = "signoz"
}

import {
  to = clickhousedbops_database.signoz_traces
  id = "signoz_traces"
}

import {
  to = clickhousedbops_database.signoz_metrics
  id = "signoz_metrics"
}

import {
  to = clickhousedbops_database.signoz_logs
  id = "signoz_logs"
}


# 1. Generate Password for SigNoz internal user
resource "random_password" "signoz_clickhouse" {
  length  = 24
  special = false
}

# 2. Store in Vault for L4 to consume
resource "vault_kv_secret_v2" "signoz_clickhouse" {
  mount               = vault_mount.kv.path
  name                = "signoz"
  delete_all_versions = true

  data_json = jsonencode({
    username = "signoz"
    password = random_password.signoz_clickhouse.result
    host     = "clickhouse.data-staging.svc.cluster.local"
    port     = "9000"
    database = "signoz_traces"
  })
}

# 3. Create SigNoz User in ClickHouse
# Uses password_sha256_hash_wo (WriteOnly - not stored in state)
resource "clickhousedbops_user" "signoz" {
  name                            = "signoz"
  password_sha256_hash_wo         = sha256(random_password.signoz_clickhouse.result)
  password_sha256_hash_wo_version = 1
}

# 4. Create SigNoz Databases
resource "clickhousedbops_database" "signoz_traces" {
  name = "signoz_traces"
}

resource "clickhousedbops_database" "signoz_metrics" {
  name = "signoz_metrics"
}

resource "clickhousedbops_database" "signoz_logs" {
  name = "signoz_logs"
}

# 5. Grant Privileges
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
