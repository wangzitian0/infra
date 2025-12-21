# =============================================================================
# ClickHouse User & Database Management for SigNoz
# Purpose: Create dedicated user and databases for SigNoz observability stack
# Layer: L2 Platform (Control Plane / Entitlements)
# =============================================================================

# Import existing resources (idempotency for pre-existing ClickHouse entities)
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
# NOTE: Privileges are managed by L3 data layer via SigNoz helm chart init.
# The clickhousedbops_grant_privilege resource has a verification bug where
# it fails if privileges already exist (expanded from ALL to individual grants).
# See: https://github.com/ClickHouse/terraform-provider-clickhousedbops/issues/XX
#
# Removed to avoid idempotency issues. Signoz user already has ALL privileges
# on signoz_traces, signoz_metrics, and signoz_logs databases.
