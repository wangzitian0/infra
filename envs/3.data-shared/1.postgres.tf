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

resource "kubernetes_namespace" "data" {
  metadata {
    name = local.namespace_name
    labels = {
      layer = "L3"
      env   = local.env_name
    }
  }
}

# =============================================================================
# Password Management (Vault-first pattern - Issue #349)
# - On first deployment: generate new password
# - On state recovery: read existing password from Vault (SSOT)
# =============================================================================

resource "random_password" "postgres" {
  length  = 24
  special = false
}

# Read existing password from Vault if it exists (Vault is SSOT)
data "external" "postgres_password" {
  program = ["bash", "-c", <<-EOT
    # Try to read password from Vault (SSOT)
    PW=$(vault kv get -field=password secret/postgres 2>/dev/null || true)
    if [ -n "$PW" ]; then
      printf '{"password": "%s", "source": "vault"}' "$PW"
    else
      printf '{"password": "", "source": "none"}'
    fi
  EOT
  ]
}

locals {
  postgres_password = data.external.postgres_password.result.password != "" ? (
    data.external.postgres_password.result.password
    ) : (
    random_password.postgres.result
  )
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
        postgresPassword = local.postgres_password
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
    password = local.postgres_password
    host     = "postgresql.${local.namespace_name}.svc.cluster.local"
    port     = "5432"
    database = "app"
  })

  depends_on = [helm_release.postgresql]

  lifecycle {
    # Don't overwrite existing password in Vault during state recovery
    ignore_changes = [data_json]
  }
}

# =============================================================================
# Vault Database Engine Configuration
# Configures Vault to use PostgreSQL root credentials for dynamic user creation
# =============================================================================

resource "vault_database_secret_backend_connection" "postgres" {
  backend       = local.vault_database_mount
  name          = "postgres"
  allowed_roles = ["postgres-readonly", "postgres-readwrite"]

  postgresql {
    connection_url = "postgres://postgres:${local.postgres_password}@postgresql.${local.namespace_name}.svc.cluster.local:5432/app?sslmode=disable"
  }

  depends_on = [helm_release.postgresql, vault_kv_secret_v2.postgres]
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
  mount               = data.terraform_remote_state.l2_platform.outputs.vault_kv_mount
  name                = data.terraform_remote_state.l2_platform.outputs.vault_db_secrets["openpanel"]
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
    redis_password = local.redis_password

    # ClickHouse (event storage) - credentials defined in 3.clickhouse.tf
    clickhouse_host     = "clickhouse.${local.namespace_name}.svc.cluster.local"
    clickhouse_port     = "9000"
    clickhouse_user     = "openpanel"
    clickhouse_password = random_password.openpanel_clickhouse.result # Defined in 3.clickhouse.tf
    clickhouse_database = "openpanel_events"
  })

  depends_on = [helm_release.postgresql, helm_release.redis, random_password.openpanel_clickhouse]
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
            env = [{
              name  = "PGPASSWORD"
              value = local.postgres_password
            }]
            command = ["/bin/sh"]
            args = ["-c", <<-EOT
              set -e
              echo "Waiting for PostgreSQL..."
              until pg_isready -h postgresql -U postgres -t 5; do sleep 2; done
              
              echo "Creating OpenPanel user..."
              psql -h postgresql -U postgres -tc "SELECT 1 FROM pg_roles WHERE rolname='openpanel'" | grep -q 1 || \
                psql -h postgresql -U postgres -c "CREATE USER openpanel WITH PASSWORD '${random_password.openpanel_postgres.result}';"
              
              echo "Creating OpenPanel database..."
              psql -h postgresql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='openpanel'" | grep -q 1 || \
                psql -h postgresql -U postgres -c "CREATE DATABASE openpanel OWNER openpanel;"
              
              echo "✅ OpenPanel PostgreSQL setup complete"
            EOT
            ]
          }]
        }
      }
    }
  })

  depends_on = [helm_release.postgresql]
}
