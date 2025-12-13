# Vault Database Secrets Engine Configuration
#
# Purpose: Configure dynamic PostgreSQL credential generation
# This file configures Vault to generate short-lived PostgreSQL credentials
# for L4 applications.

# =============================================================================
# Prerequisites
# =============================================================================
# 1. Vault Database Secrets Engine enabled at `database/`
# 2. L3 PostgreSQL deployed with root password in Vault KV

# =============================================================================
# Data: Read L3 PostgreSQL root credentials from Vault KV
# =============================================================================

data "vault_kv_secret_v2" "l3_postgres" {
  mount = "secret"
  name  = "data/postgres"
}

# =============================================================================
# Vault Database Connection for L3 PostgreSQL
# =============================================================================

resource "vault_database_secret_backend_connection" "l3_postgres" {
  backend       = "database"
  name          = "l3-postgres"
  allowed_roles = ["app-readonly", "app-readwrite"]

  postgresql {
    connection_url = format(
      "postgres://%s:%s@%s:%s/%s?sslmode=disable",
      data.vault_kv_secret_v2.l3_postgres.data["username"],
      data.vault_kv_secret_v2.l3_postgres.data["password"],
      data.vault_kv_secret_v2.l3_postgres.data["host"],
      data.vault_kv_secret_v2.l3_postgres.data["port"],
      data.vault_kv_secret_v2.l3_postgres.data["database"]
    )
  }
}

# =============================================================================
# Vault Roles for Dynamic Credential Generation
# =============================================================================

# Readonly role for app queries
resource "vault_database_secret_backend_role" "app_readonly" {
  backend             = "database"
  name                = "app-readonly"
  db_name             = vault_database_secret_backend_connection.l3_postgres.name
  default_ttl         = 3600  # 1 hour
  max_ttl             = 86400 # 24 hours

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
  backend             = "database"
  name                = "app-readwrite"
  db_name             = vault_database_secret_backend_connection.l3_postgres.name
  default_ttl         = 3600  # 1 hour
  max_ttl             = 86400 # 24 hours

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
