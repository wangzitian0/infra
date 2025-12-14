# Vault Database Secrets Engine Configuration
#
# Purpose: Configure dynamic PostgreSQL credential generation
# This file manages:
# 1. Vault secrets engines (KV + database)
# 2. L3 PostgreSQL root password (generated here, used by L3)
# 3. Dynamic credential roles for L4 applications
#
# Note: L3 namespaces (data-staging, data-prod) are created by L3 workspaces
# Note: All resources are conditional on vault_root_token being set (local.vault_enabled)
#       This allows CI to skip Vault config when Vault server is unreachable

# =============================================================================
# Vault Secrets Engines (IaC - replaces manual vault secrets enable)
# =============================================================================

# KV v2 secrets engine for static secrets (L3 PostgreSQL root password)
resource "vault_mount" "kv" {
  count = local.vault_enabled ? 1 : 0

  path        = "secret"
  type        = "kv-v2"
  description = "KV v2 secrets engine for L3 static secrets"
}

# Database secrets engine for dynamic credentials
resource "vault_mount" "database" {
  count = local.vault_enabled ? 1 : 0

  path        = "database"
  type        = "database"
  description = "Database secrets engine for L3 PostgreSQL dynamic credentials"
}

# =============================================================================
# L3 PostgreSQL Root Password (generated in L2, consumed by L3)
# =============================================================================

# Generate password for L3 PostgreSQL root user
resource "random_password" "l3_postgres" {
  count   = local.vault_enabled ? 1 : 0
  length  = 24
  special = false
}

# Store L3 PostgreSQL credentials in Vault KV
resource "vault_kv_secret_v2" "l3_postgres" {
  count               = local.vault_enabled ? 1 : 0
  mount               = vault_mount.kv[0].path
  name                = "data/postgres"
  delete_all_versions = true

  data_json = jsonencode({
    username = "postgres"
    password = random_password.l3_postgres[0].result
    host     = "postgresql.data-staging.svc.cluster.local"
    port     = "5432"
    database = "app"
  })
}

# =============================================================================
# L3 Redis Password (generated in L2, consumed by L3)
# =============================================================================

# Generate password for L3 Redis
resource "random_password" "l3_redis" {
  count   = local.vault_enabled ? 1 : 0
  length  = 32
  special = false
}

# Store L3 Redis credentials in Vault KV
resource "vault_kv_secret_v2" "l3_redis" {
  count               = local.vault_enabled ? 1 : 0
  mount               = vault_mount.kv[0].path
  name                = "data/redis"
  delete_all_versions = true

  data_json = jsonencode({
    password = random_password.l3_redis[0].result
    host     = "redis-master.data.svc.cluster.local"
    port     = "6379"
  })
}

# =============================================================================
# L3 ClickHouse Password (generated in L2, consumed by L3)
# =============================================================================

# Generate password for L3 ClickHouse
resource "random_password" "l3_clickhouse" {
  count   = local.vault_enabled ? 1 : 0
  length  = 32
  special = false
}

# Store L3 ClickHouse credentials in Vault KV
resource "vault_kv_secret_v2" "l3_clickhouse" {
  count               = local.vault_enabled ? 1 : 0
  mount               = vault_mount.kv[0].path
  name                = "data/clickhouse"
  delete_all_versions = true

  data_json = jsonencode({
    username = "default"
    password = random_password.l3_clickhouse[0].result
    host     = "clickhouse.data.svc.cluster.local"
    port     = "9000"
    database = "default"
  })
}

# =============================================================================
# L3 ArangoDB Password (generated in L2, consumed by L3)
# =============================================================================

# Generate password for L3 ArangoDB
resource "random_password" "l3_arangodb" {
  count   = local.vault_enabled ? 1 : 0
  length  = 32
  special = false
}

# Generate JWT secret for ArangoDB (32 bytes minimum)
resource "random_bytes" "l3_arangodb_jwt" {
  count  = local.vault_enabled ? 1 : 0
  length = 32
}

# Store L3 ArangoDB credentials in Vault KV
resource "vault_kv_secret_v2" "l3_arangodb" {
  count               = local.vault_enabled ? 1 : 0
  mount               = vault_mount.kv[0].path
  name                = "data/arangodb"
  delete_all_versions = true

  data_json = jsonencode({
    username   = "root"
    password   = random_password.l3_arangodb[0].result
    jwt_secret = random_bytes.l3_arangodb_jwt[0].base64
    host       = "arangodb.data.svc.cluster.local"
    port       = "8529"
  })
}


# =============================================================================
# Vault Database Connection for L3 PostgreSQL
# NOTE: Enable only after L3 PostgreSQL is deployed (set enable_postgres_backend=true)
# =============================================================================

resource "vault_database_secret_backend_connection" "l3_postgres" {
  count         = local.vault_enabled && var.enable_postgres_backend ? 1 : 0
  backend       = vault_mount.database[0].path
  name          = "l3-postgres"
  allowed_roles = ["app-readonly", "app-readwrite"]

  postgresql {
    connection_url = "postgres://postgres:${random_password.l3_postgres[0].result}@postgresql.data-staging.svc.cluster.local:5432/app?sslmode=disable"
  }

  depends_on = [vault_kv_secret_v2.l3_postgres]
}

# =============================================================================
# Vault Roles for Dynamic Credential Generation
# =============================================================================

# Readonly role for app queries
resource "vault_database_secret_backend_role" "app_readonly" {
  count       = local.vault_enabled && var.enable_postgres_backend ? 1 : 0
  backend     = vault_mount.database[0].path
  name        = "app-readonly"
  db_name     = vault_database_secret_backend_connection.l3_postgres[0].name
  default_ttl = 3600  # 1 hour
  max_ttl     = 86400 # 24 hours

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
    "GRANT USAGE ON SCHEMA public TO \"{{name}}\";"
  ]

  revocation_statements = [
    "REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM \"{{name}}\";",
    "DROP ROLE IF EXISTS \"{{name}}\";"
  ]
}

# Readwrite role for app CRUD operations
resource "vault_database_secret_backend_role" "app_readwrite" {
  count       = local.vault_enabled && var.enable_postgres_backend ? 1 : 0
  backend     = vault_mount.database[0].path
  name        = "app-readwrite"
  db_name     = vault_database_secret_backend_connection.l3_postgres[0].name
  default_ttl = 3600  # 1 hour
  max_ttl     = 86400 # 24 hours

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
    "GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO \"{{name}}\";",
    "GRANT USAGE ON SCHEMA public TO \"{{name}}\";"
  ]

  revocation_statements = [
    "REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM \"{{name}}\";",
    "REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM \"{{name}}\";",
    "DROP ROLE IF EXISTS \"{{name}}\";"
  ]
}

# =============================================================================
# Outputs
# =============================================================================

output "vault_db_roles" {
  description = "Available Vault database roles for L3 PostgreSQL"
  value = local.vault_enabled ? {
    readonly  = "vault read database/creds/app-readonly"
    readwrite = "vault read database/creds/app-readwrite"
  } : null
}

output "vault_mounts" {
  description = "Vault secrets engine mount paths"
  value = local.vault_enabled ? {
    kv       = vault_mount.kv[0].path
    database = vault_mount.database[0].path
  } : null
}

output "l3_postgres_vault_path" {
  description = "Vault KV path for L3 PostgreSQL credentials"
  value       = local.vault_enabled ? "${vault_mount.kv[0].path}/data/postgres" : null
}

output "l3_redis_vault_path" {
  description = "Vault KV path for L3 Redis credentials"
  value       = local.vault_enabled ? "${vault_mount.kv[0].path}/data/redis" : null
}

output "l3_clickhouse_vault_path" {
  description = "Vault KV path for L3 ClickHouse credentials"
  value       = local.vault_enabled ? "${vault_mount.kv[0].path}/data/clickhouse" : null
}

output "l3_arangodb_vault_path" {
  description = "Vault KV path for L3 ArangoDB credentials"
  value       = local.vault_enabled ? "${vault_mount.kv[0].path}/data/arangodb" : null
}

