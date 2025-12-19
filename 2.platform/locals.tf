locals {
  internal_domain         = var.internal_domain != "" ? var.internal_domain : var.base_domain
  portal_sso_gate_enabled = var.enable_portal_sso_gate
  # Vault resources only created when vault_root_token is provided
  # This allows CI to skip Vault config when Vault is unreachable
  # Use nonsensitive() to avoid tainting outputs as sensitive
  vault_enabled = nonsensitive(var.vault_root_token) != ""

  # =============================================================================
  # Vault KV v2 SSOT - Single Source of Truth for all L3 DB secrets
  # Issue #301: Centralized path definitions to eliminate hardcoding
  # =============================================================================
  vault_kv_mount = "secret"

  # Database secret names in Vault KV (used by L2 resources and exported for L3/CI)
  vault_db_secrets = {
    postgres   = "postgres"
    redis      = "redis"
    clickhouse = "clickhouse"
    arangodb   = "arangodb"
  }

  # Full Vault API paths (for documentation and reference)
  # Format: mount/data/name (KV v2 auto-adds /data/)
  vault_secret_paths = {
    for k, v in local.vault_db_secrets : k => "${local.vault_kv_mount}/data/${v}"
  }
}
