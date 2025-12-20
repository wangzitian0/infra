# =============================================================================
# SigNoz ClickHouse Password (generated in L2, consumed by L3/L4)
# =============================================================================

# Generate password for SigNoz ClickHouse user
resource "random_password" "signoz_clickhouse" {
  length  = 24
  special = false
}

# Store SigNoz ClickHouse credentials in Vault KV
resource "vault_kv_secret_v2" "signoz_clickhouse" {
  mount               = vault_mount.kv.path
  name                = local.vault_db_secrets["signoz"]
  delete_all_versions = true

  data_json = jsonencode({
    username = "signoz"
    password = random_password.signoz_clickhouse.result
    # Host/port are same as main ClickHouse, but good to have for reference
    host     = "clickhouse.data-staging.svc.cluster.local"
    port     = "9000"
    database = "signoz_traces"
  })
}
