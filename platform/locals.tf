locals {
  internal_domain         = var.internal_domain != "" ? var.internal_domain : var.base_domain
  portal_sso_gate_enabled = var.enable_portal_sso_gate
  casdoor_oidc_enabled    = local.casdoor_enabled && coalesce(var.enable_casdoor_oidc, var.enable_portal_sso_gate)
  # Vault resources only created when vault_root_token is provided
  # This allows CI to skip Vault config when Vault is unreachable
  # Use nonsensitive() to avoid tainting outputs as sensitive
  vault_enabled = nonsensitive(var.vault_root_token) != ""

  # =============================================================================
  # Vault KV v2 SSOT - Single Source of Truth for all Data DB secrets
  # Issue #301: Centralized path definitions
  # Data layer reads these via terraform_remote_state
  # =============================================================================
  vault_kv_mount = "secret"

  vault_db_secrets = {
    postgres   = "postgres"
    redis      = "redis"
    clickhouse = "clickhouse"
    arangodb   = "arangodb"
    openpanel  = "openpanel"
  }

  vault_secret_paths = {
    for k, v in local.vault_db_secrets : k => "${local.vault_kv_mount}/data/${v}"
  }
}

# Read 'simpleuser' credentials from Kubernetes Secret (managed by Bootstrap layer)
data "kubernetes_secret" "platform_pg_simpleuser" {
  metadata {
    name      = "platform-pg-simpleuser"
    namespace = data.kubernetes_namespace.platform.metadata[0].name
  }
}
