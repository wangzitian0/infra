# Vault Configuration Module
# SSOT for all Vault paths across L2/L3/L4 layers
#
# Usage:
#   module "vault_config" {
#     source = "../modules/vault-config"
#   }
#
# Issue #301: Centralized Vault path definitions

output "vault_kv_mount" {
  description = "Vault KV v2 mount path"
  value       = "secret"
}

output "vault_db_secrets" {
  description = "Map of DB type to secret name in Vault KV"
  value = {
    postgres   = "postgres"
    redis      = "redis"
    clickhouse = "clickhouse"
    arangodb   = "arangodb"
  }
}

output "vault_secret_paths" {
  description = "Full Vault API paths (mount/data/name) for reference"
  value = {
    postgres   = "secret/data/postgres"
    redis      = "secret/data/redis"
    clickhouse = "secret/data/clickhouse"
    arangodb   = "secret/data/arangodb"
  }
}
