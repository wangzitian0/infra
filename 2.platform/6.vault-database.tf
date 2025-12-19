# Vault Database Secrets Engine Configuration
#
# Purpose: Configure dynamic PostgreSQL credential generation
# This file manages:
# 1. Vault secrets engines (KV + database)
# 2. L3 PostgreSQL root password (generated here, used by L3)
# 3. Dynamic credential roles for L4 applications
#
# Note: L3 namespaces (data-staging, data-prod) are created by L3 workspaces

# =============================================================================
# Vault Secrets Engines (IaC - replaces manual vault secrets enable)
# =============================================================================

# KV v2 secrets engine for static secrets (L3 PostgreSQL root password)
resource "vault_mount" "kv" {
  path        = "secret"
  type        = "kv-v2"
  description = "KV v2 secrets engine for L3 static secrets"

  lifecycle {
    precondition {
      condition     = var.vault_root_token != ""
      error_message = "vault_root_token is required for Vault secrets engine configuration."
    }

    postcondition {
      condition     = self.accessor != ""
      error_message = "Vault KV mount failed - accessor is empty. Check Vault connectivity and permissions."
    }
  }
}

# Database secrets engine for dynamic credentials
resource "vault_mount" "database" {
  path        = "database"
  type        = "database"
  description = "Database secrets engine for L3 PostgreSQL dynamic credentials"
}

# =============================================================================
# L3 PostgreSQL Root Password (generated in L2, consumed by L3)
# =============================================================================

# Generate password for L3 PostgreSQL root user
resource "random_password" "l3_postgres" {
  length  = 24
  special = false
}

# Store L3 PostgreSQL credentials in Vault KV
resource "vault_kv_secret_v2" "l3_postgres" {
  mount               = vault_mount.kv.path
  name                = "data/postgres"
  delete_all_versions = true

  data_json = jsonencode({
    username = "postgres"
    password = random_password.l3_postgres.result
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
  length  = 32
  special = false
}

# Store L3 Redis credentials in Vault KV
resource "vault_kv_secret_v2" "l3_redis" {
  mount               = vault_mount.kv.path
  name                = "data/redis"
  delete_all_versions = true

  data_json = jsonencode({
    password = random_password.l3_redis.result
    host     = "redis-master.data.svc.cluster.local"
    port     = "6379"
  })
}

# =============================================================================
# L3 ClickHouse Password (generated in L2, consumed by L3)
# =============================================================================

# Generate password for L3 ClickHouse
resource "random_password" "l3_clickhouse" {
  length  = 32
  special = false
}

# Store L3 ClickHouse credentials in Vault KV
resource "vault_kv_secret_v2" "l3_clickhouse" {
  mount               = vault_mount.kv.path
  name                = "data/clickhouse"
  delete_all_versions = true

  data_json = jsonencode({
    username = "default"
    password = random_password.l3_clickhouse.result
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
  length  = 32
  special = false
}

# Generate JWT secret for ArangoDB (32 bytes minimum)
resource "random_bytes" "l3_arangodb_jwt" {
  length = 32
}

# Store L3 ArangoDB credentials in Vault KV
resource "vault_kv_secret_v2" "l3_arangodb" {
  mount               = vault_mount.kv.path
  name                = "data/arangodb"
  delete_all_versions = true

  data_json = jsonencode({
    username   = "root"
    password   = random_password.l3_arangodb.result
    jwt_secret = random_bytes.l3_arangodb_jwt.base64
    host       = "arangodb.data.svc.cluster.local"
    port       = "8529"
  })
}


# =============================================================================
# Vault Database Connection for L3 PostgreSQL
# NOTE: Enable only after L3 PostgreSQL is deployed (set enable_postgres_backend=true)
# =============================================================================

resource "vault_database_secret_backend_connection" "l3_postgres" {
  count         = var.enable_postgres_backend ? 1 : 0
  backend       = vault_mount.database.path
  name          = "l3-postgres"
  allowed_roles = ["app-readonly", "app-readwrite"]

  postgresql {
    connection_url = "postgres://postgres:${random_password.l3_postgres.result}@postgresql.data-staging.svc.cluster.local:5432/app?sslmode=disable"
  }

  depends_on = [vault_kv_secret_v2.l3_postgres]
}

# =============================================================================
# Vault Roles for Dynamic Credential Generation
# =============================================================================

# Readonly role for app queries
resource "vault_database_secret_backend_role" "app_readonly" {
  count       = var.enable_postgres_backend ? 1 : 0
  backend     = vault_mount.database.path
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
  count       = var.enable_postgres_backend ? 1 : 0
  backend     = vault_mount.database.path
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
  value = {
    readonly  = "vault read database/creds/app-readonly"
    readwrite = "vault read database/creds/app-readwrite"
  }
}

output "vault_mounts" {
  description = "Vault secrets engine mount paths"
  value = {
    kv       = vault_mount.kv.path
    database = vault_mount.database.path
  }
}

output "l3_postgres_vault_path" {
  description = "Vault KV path for L3 PostgreSQL credentials"
  value       = "${vault_mount.kv.path}/data/postgres"
}

output "l3_redis_vault_path" {
  description = "Vault KV path for L3 Redis credentials"
  value       = "${vault_mount.kv.path}/data/redis"
}

output "l3_clickhouse_vault_path" {
  description = "Vault KV path for L3 ClickHouse credentials"
  value       = "${vault_mount.kv.path}/data/clickhouse"
}

output "l3_arangodb_vault_path" {
  description = "Vault KV path for L3 ArangoDB credentials"
  value       = "${vault_mount.kv.path}/data/arangodb"
}

