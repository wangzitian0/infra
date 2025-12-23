# Purpose: PostgreSQL for business applications

#
# Architecture (VSO Pattern - Issue #351):
# - random_password generates password on first deploy
# - vault_kv_secret_v2 stores password in Vault (SSOT)
# - VaultStaticSecret syncs Vault → K8s Secret (via VSO)
# - Helm uses existingSecret to read from K8s Secret
# - Vault Database Engine uses random_password with ignore_changes
#
# Pattern: Bitnami Helm chart (matches L1 platform_pg)
# Note: Bitnami deletes old image tags, so we use 'latest' with IfNotPresent

# =============================================================================
# Namespace (per-environment: data-staging, data-prod)
# =============================================================================

resource "kubernetes_namespace" "data" {
  metadata {
    name = local.namespace_name
    labels = {
      module = "data"
      env    = local.env_name
    }
  }
}

# =============================================================================
# Password Management (VSO Pattern - Issue #351)
# - random_password generates password on first deployment
# - vault_kv_secret_v2 stores password in Vault (SSOT)
# - VaultStaticSecret syncs Vault → K8s Secret (via VSO)
# - Helm uses existingSecret to read from K8s Secret
# =============================================================================

resource "random_password" "postgres" {
  length  = 24
  special = false
}

# =============================================================================
# Vault KV Storage (store password - SSOT)
# Must be created BEFORE VaultStaticSecret can sync it
# =============================================================================

resource "vault_kv_secret_v2" "postgres" {
  mount               = data.terraform_remote_state.platform.outputs.vault_kv_mount
  name                = data.terraform_remote_state.platform.outputs.vault_db_secrets["postgres"]
  delete_all_versions = true

  data_json = jsonencode({
    username = "postgres"
    password = random_password.postgres.result
    host     = "postgresql.${local.namespace_name}.svc.cluster.local"
    port     = "5432"
    database = "app"
  })

  depends_on = [kubernetes_namespace.data]

  lifecycle {
    # Don't overwrite existing password in Vault during state recovery
    ignore_changes = [data_json]
  }
}

# =============================================================================
# VaultStaticSecret - Syncs Vault KV → K8s Secret (via VSO)
# =============================================================================

resource "kubectl_manifest" "postgres_vault_secret" {
  yaml_body = yamlencode({
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultStaticSecret"
    metadata = {
      name      = "postgresql-credentials"
      namespace = local.namespace_name
    }
    spec = {
      type  = "kv-v2"
      mount = data.terraform_remote_state.platform.outputs.vault_kv_mount
      path  = data.terraform_remote_state.platform.outputs.vault_db_secrets["postgres"]
      destination = {
        name   = "postgresql-credentials"
        create = true
      }
      refreshAfter = "1h"
      vaultAuthRef = "default"
    }
  })

  depends_on = [vault_kv_secret_v2.postgres, kubectl_manifest.vault_auth]
}

# Wait for VSO to sync the secret before Helm tries to use it
resource "time_sleep" "wait_for_postgres_secret" {
  create_duration = "15s"
  depends_on      = [kubectl_manifest.postgres_vault_secret]
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
        # Use existingSecret created by VSO (synced from Vault KV)
        existingSecret = "postgresql-credentials"
        secretKeys = {
          adminPasswordKey = "password"
        }
        database = "app"
      }
      primary = {
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

  depends_on = [time_sleep.wait_for_postgres_secret]

  lifecycle {
    postcondition {
      condition     = self.status == "deployed"
      error_message = "PostgreSQL Helm release failed to deploy. Check pod logs and events."
    }
  }
}

# =============================================================================
# Vault Database Engine Configuration
# Configures Vault to use PostgreSQL root credentials for dynamic user creation
# Note: Uses random_password directly; ignore_changes for state recovery
# =============================================================================

resource "vault_database_secret_backend_connection" "postgres" {
  backend       = local.vault_database_mount
  name          = "postgres"
  allowed_roles = ["postgres-readonly", "postgres-readwrite"]

  postgresql {
    connection_url = "postgres://postgres:${random_password.postgres.result}@postgresql.${local.namespace_name}.svc.cluster.local:5432/app?sslmode=disable"
  }

  depends_on = [helm_release.postgresql, vault_kv_secret_v2.postgres]

  lifecycle {
    # Don't update connection if state is recovered (password would be wrong)
    ignore_changes = [postgresql]
  }
}

# =============================================================================
# Vault Roles for Dynamic Credential Generation
# =============================================================================

# Readonly role for app queries
resource "vault_database_secret_backend_role" "postgres_readonly" {
  backend     = local.vault_database_mount
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
  backend     = local.vault_database_mount
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
  value       = "${data.terraform_remote_state.platform.outputs.vault_kv_mount}/data/${data.terraform_remote_state.platform.outputs.vault_db_secrets["postgres"]}"
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

# =============================================================================
# OpenPanel PostgreSQL User & Database (Static Credentials)
# Purpose: Dedicated database for OpenPanel analytics
# Note: OpenPanel requires a dedicated database, not shared with "app"
# =============================================================================

# Generate password for OpenPanel PostgreSQL user
resource "random_password" "openpanel_postgres" {
  length  = 24
  special = false
}

# Store OpenPanel credentials in Vault KV for L4 to consume
resource "vault_kv_secret_v2" "openpanel" {
  mount               = data.terraform_remote_state.platform.outputs.vault_kv_mount
  name                = data.terraform_remote_state.platform.outputs.vault_db_secrets["openpanel"]
  delete_all_versions = true

  data_json = jsonencode({
    # PostgreSQL (primary database)
    postgres_host     = "postgresql.${local.namespace_name}.svc.cluster.local"
    postgres_port     = "5432"
    postgres_user     = "openpanel"
    postgres_password = random_password.openpanel_postgres.result
    postgres_database = "openpanel"

    # Redis (cache/queue) - shared L3 instance
    redis_host     = "redis-master.${local.namespace_name}.svc.cluster.local"
    redis_port     = "6379"
    redis_password = random_password.redis.result # Direct reference to random_password

    # ClickHouse (event storage) - credentials defined in 3.clickhouse.tf
    clickhouse_host     = "clickhouse.${local.namespace_name}.svc.cluster.local"
    clickhouse_port     = "9000"
    clickhouse_user     = "openpanel"
    clickhouse_password = random_password.openpanel_clickhouse.result # Defined in 3.clickhouse.tf
    clickhouse_database = "openpanel_events"
  })

  depends_on = [helm_release.postgresql, helm_release.redis, random_password.openpanel_clickhouse]

  lifecycle {
    # Don't overwrite existing credentials in Vault during state recovery
    ignore_changes = [data_json]
  }
}

# Create OpenPanel user and database via init Job
# This runs once after PostgreSQL is ready
resource "kubectl_manifest" "openpanel_postgres_init" {
  yaml_body = yamlencode({
    apiVersion = "batch/v1"
    kind       = "Job"
    metadata = {
      name      = "openpanel-postgres-init"
      namespace = local.namespace_name
      labels = {
        app     = "openpanel"
        purpose = "db-init"
      }
    }
    spec = {
      backoffLimit            = 3
      ttlSecondsAfterFinished = 86400 # 24 hours
      template = {
        spec = {
          restartPolicy = "OnFailure"
          containers = [{
            name  = "psql-init"
            image = "postgres:16-alpine"
            env = [
              {
                name = "PGPASSWORD"
                valueFrom = {
                  secretKeyRef = {
                    name = "postgresql-credentials"
                    key  = "password"
                  }
                }
              },
              {
                name  = "OPENPANEL_PASSWORD"
                value = random_password.openpanel_postgres.result
              }
            ]
            command = ["/bin/sh"]
            args = ["-c", <<-EOT
              set -e
              echo "Waiting for PostgreSQL..."
              until pg_isready -h postgresql -U postgres -t 5; do sleep 2; done

              echo "Creating OpenPanel user..."
              psql -h postgresql -U postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='openpanel'" | grep -q 1 || \
                psql -h postgresql -U postgres -c "CREATE USER openpanel WITH PASSWORD '$OPENPANEL_PASSWORD';"

              echo "Creating OpenPanel database..."
              psql -h postgresql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='openpanel'" | grep -q 1 || \
                psql -h postgresql -U postgres -c "CREATE DATABASE openpanel OWNER openpanel;"

              echo "OpenPanel PostgreSQL setup complete"
            EOT
            ]
          }]
        }
      }
    }
  })

  depends_on = [helm_release.postgresql, kubectl_manifest.postgres_vault_secret]
}
