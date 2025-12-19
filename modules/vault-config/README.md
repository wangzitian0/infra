# Vault Config Module
#
# This module provides centralized Vault configuration for all layers.
# It is the Single Source of Truth (SSOT) for Vault paths.
#
# ## Usage
#
# ```hcl
# module "vault_config" {
#   source = "../modules/vault-config"
# }
#
# # Then reference:
# # module.vault_config.vault_kv_mount
# # module.vault_config.vault_db_secrets["postgres"]
# # module.vault_config.vault_secret_paths["postgres"]
# ```
#
# ## Outputs
#
# | Output | Description |
# |--------|-------------|
# | `vault_kv_mount` | KV v2 mount path ("secret") |
# | `vault_db_secrets` | Map of DB → secret name |
# | `vault_secret_paths` | Full API paths for documentation |
#
# ## Issue
#
# Created for Issue #301 - eliminating Vault path hardcoding.
