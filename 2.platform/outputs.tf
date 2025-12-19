# =============================================================================
# Vault SSOT Outputs (Issue #301)
# Export centralized Vault path definitions for downstream consumers
# =============================================================================

output "vault_kv_mount" {
  description = "Vault KV v2 mount path"
  value       = module.vault_config.vault_kv_mount
}

output "vault_db_secrets" {
  description = "Map of DB type to secret name in Vault KV"
  value       = module.vault_config.vault_db_secrets
}

output "vault_secret_paths" {
  description = "Full Vault API paths (mount/data/name) for each DB secret"
  value       = module.vault_config.vault_secret_paths
}
