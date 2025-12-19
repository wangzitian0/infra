# =============================================================================
# Vault SSOT Outputs (Issue #301)
# Export centralized Vault path definitions for downstream consumers (L3/L4)
# L3 reads these via terraform_remote_state
# =============================================================================

output "vault_kv_mount" {
  description = "Vault KV v2 mount path"
  value       = local.vault_kv_mount
}

output "vault_db_secrets" {
  description = "Map of DB type to secret name in Vault KV"
  value       = local.vault_db_secrets
}

output "vault_secret_paths" {
  description = "Full Vault API paths (mount/data/name) for each DB secret"
  value       = local.vault_secret_paths
}
