# L3 Business PostgreSQL
#
# Purpose: PostgreSQL for business applications (L4)
#
# Architecture (after refactor - Issue #336):
# - L3 generates password locally
# - L3 stores password in Vault KV
# - L3 configures Vault Database Engine for dynamic credentials
# - L4 uses Vault dynamic credentials
#
# Pattern: Bitnami Helm chart (matches L1 platform_pg)
# Note: Bitnami deletes old image tags, so we use 'latest' with IfNotPresent

# =============================================================================
# Namespace (per-environment: data-staging, data-prod)
# =============================================================================

locals {
  namespace_name = "data-${terraform.workspace}"
}

resource "kubernetes_namespace" "data" {
  metadata {
    name = local.namespace_name
    labels = {
      layer = "L3"
      env   = terraform.workspace
    }
  }
}

# =============================================================================
# Password Generation (generated in L3, stored in Vault)
# =============================================================================

resource "random_password" "postgres" {
  length  = 24
  special = false
}

# =============================================================================
# PostgreSQL via Bitnami Helm chart
# =============================================================================

resource "helm_release" "postgresql" {
  name             = "postgresql"
  namespace        = kubernetes_namespace.data.metadata[0].name
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "postgresql"
  version          = "16.4.2"
  create_namespace = false
  timeout          = 300
  wait             = true
  wait_for_jobs    = true

  values = [
    yamlencode({
      # Bitnami deletes old tags; use latest + IfNotPresent to reduce drift
      image = {
        tag        = "latest"
        pullPolicy = "IfNotPresent"
      }
      auth = {
        postgresPassword = random_password.postgres.result
        database         = "app"
      }
      primary = {
        # Wait for Vault to be available (max 120s timeout)
        initContainers = [
          {
            name  = "wait-for-vault"
            image = "busybox:1.36"
            command = [
              "sh", "-c",
              "t=120;e=0;until nc -z vault.platform.svc.cluster.local 8200;do echo \"waiting for Vault... ($e/$t s)\";sleep 2;e=$((e+2));[ $e -ge $t ]&&exit 1;done"
            ]
          }
        ]
        persistence = {
          enabled      = true
          storageClass = "local-path-retain"
          size         = "10Gi"
        }
        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }
    })
  ]

  lifecycle {
    postcondition {
      condition     = self.status == "deployed"
      error_message = "PostgreSQL Helm release failed to deploy. Check pod logs and events."
    }
  }
}

# =============================================================================
# Vault KV Storage (store password for reference and DB Engine config)
# =============================================================================

resource "vault_kv_secret_v2" "postgres" {
  mount               = data.terraform_remote_state.l2_platform.outputs.vault_kv_mount
  name                = data.terraform_remote_state.l2_platform.outputs.vault_db_secrets["postgres"]
  delete_all_versions = true

  data_json = jsonencode({
    username = "postgres"
    password = random_password.postgres.result
    host     = "postgresql.${local.namespace_name}.svc.cluster.local"
    port     = "5432"
    database = "app"
  })

  depends_on = [helm_release.postgresql]
}

# =============================================================================
# Vault Database Engine Configuration
# Configures Vault to use PostgreSQL root credentials for dynamic user creation
# =============================================================================

resource "vault_database_secret_backend_connection" "postgres" {
  backend       = data.terraform_remote_state.l2_platform.outputs.vault_database_mount
  name          = "postgres"
  allowed_roles = ["postgres-readonly", "postgres-readwrite"]

  postgresql {
    connection_url = "postgres://postgres:${random_password.postgres.result}@postgresql.${local.namespace_name}.svc.cluster.local:5432/app?sslmode=disable"
  }

  depends_on = [helm_release.postgresql, vault_kv_secret_v2.postgres]
}

# =============================================================================
# Vault Roles for Dynamic Credential Generation
# =============================================================================

# Readonly role for app queries
resource "vault_database_secret_backend_role" "postgres_readonly" {
  backend     = data.terraform_remote_state.l2_platform.outputs.vault_database_mount
  name        = "postgres-readonly"
  db_name     = vault_database_secret_backend_connection.postgres.name
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
resource "vault_database_secret_backend_role" "postgres_readwrite" {
  backend     = data.terraform_remote_state.l2_platform.outputs.vault_database_mount
  name        = "postgres-readwrite"
  db_name     = vault_database_secret_backend_connection.postgres.name
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

output "postgres_host" {
  value       = "postgresql.${local.namespace_name}.svc.cluster.local"
  description = "PostgreSQL K8s service DNS"
}

output "postgres_vault_path" {
  value       = "${data.terraform_remote_state.l2_platform.outputs.vault_kv_mount}/data/${data.terraform_remote_state.l2_platform.outputs.vault_db_secrets["postgres"]}"
  description = "Vault KV path for PostgreSQL credentials"
}

output "postgres_namespace" {
  value       = local.namespace_name
  description = "Namespace where PostgreSQL is deployed"
}

output "postgres_vault_roles" {
  description = "Available Vault database roles for PostgreSQL"
  value = {
    readonly  = "vault read database/creds/postgres-readonly"
    readwrite = "vault read database/creds/postgres-readwrite"
  }
}
