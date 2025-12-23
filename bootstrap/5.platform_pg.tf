# L1.5: Platform PostgreSQL - Trust Anchor Database
# Purpose: Shared database for L2 platform services (Vault, Casdoor)
# Note: Deployed in L1 to avoid circular dependency with Vault
#
# Why L1?
# - Vault needs DB → Services need Vault → Can't use Vault to manage Vault's DB
# - This breaks SSOT intentionally as Trust Anchor
#
# Consumers:
# - Vault (L2): storage backend
# - Casdoor (L2): user/session data

locals {
  platform_pg_host        = "postgresql.platform.svc.cluster.local"
  platform_pg_init_script = <<-SCRIPT
    #!/bin/sh
    set -eu

    for i in $(seq 1 30); do
      if pg_isready -h "$${PGHOST}" -U "$${PGUSER}" >/dev/null 2>&1; then
        break
      fi
      sleep 2
    done

    if ! pg_isready -h "$${PGHOST}" -U "$${PGUSER}" >/dev/null 2>&1; then
      echo "PostgreSQL not ready after waiting." >&2
      exit 1
    fi

    # Idempotent: create Casdoor database if missing
    psql -h "$${PGHOST}" -U "$${PGUSER}" -tc "SELECT 1 FROM pg_database WHERE datname = 'casdoor'" | grep -q 1 || \
      psql -h "$${PGHOST}" -U "$${PGUSER}" -c "CREATE DATABASE casdoor"

    # Idempotent: create Vault tables if missing
    psql -h "$${PGHOST}" -U "$${PGUSER}" -d vault <<'SQL'
      CREATE TABLE IF NOT EXISTS vault_kv_store (
        parent_path TEXT COLLATE "C" NOT NULL,
        path        TEXT COLLATE "C",
        key         TEXT COLLATE "C",
        value       BYTEA,
        CONSTRAINT pkey PRIMARY KEY (path, key)
      );
      CREATE INDEX IF NOT EXISTS parent_path_idx ON vault_kv_store (parent_path);

      CREATE TABLE IF NOT EXISTS vault_ha_locks (
        ha_key      TEXT COLLATE "C" NOT NULL,
        ha_identity TEXT COLLATE "C" NOT NULL,
        ha_value    TEXT COLLATE "C",
        valid_until TIMESTAMP WITH TIME ZONE NOT NULL,
        CONSTRAINT ha_key PRIMARY KEY (ha_key)
      );

      SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE 'vault_%';
SQL
  SCRIPT
  platform_pg_init_hash   = substr(sha1(local.platform_pg_init_script), 0, 8)
}

# Create/manage platform namespace in L1 (before L2 Vault deployment)
resource "kubernetes_namespace" "platform" {
  metadata {
    name = "platform"
    labels = {
      layer = "L2"
    }
  }
}

# Platform PostgreSQL via Bitnami Helm chart
# Note: Bitnami deletes old image tags, so we use 'latest' with IfNotPresent
resource "helm_release" "platform_pg" {
  name             = "postgresql"
  namespace        = kubernetes_namespace.platform.metadata[0].name
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
        postgresPassword = var.vault_postgres_password
        database         = "vault"
      }
      primary = {
        persistence = {
          enabled      = true
          storageClass = "local-path-retain"
          size         = var.vault_postgres_storage
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
      metrics = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_namespace.platform]

  lifecycle {
    precondition {
      condition     = length(var.vault_postgres_password) >= 16
      error_message = "vault_postgres_password must be at least 16 characters."
    }
  }
}

# Vault tables + Casdoor database initialization (idempotent)
resource "kubectl_manifest" "platform_pg_init" {
  yaml_body = yamlencode({
    apiVersion = "batch/v1"
    kind       = "Job"
    metadata = {
      name      = "platform-pg-init-${local.platform_pg_init_hash}"
      namespace = kubernetes_namespace.platform.metadata[0].name
    }
    spec = {
      backoffLimit = 3
      template = {
        metadata = {
          labels = {
            app = "platform-pg-init"
          }
        }
        spec = {
          restartPolicy = "OnFailure"
          containers = [
            {
              name    = "psql"
              image   = "postgres:16"
              command = ["/bin/sh", "-c"]
              args    = [local.platform_pg_init_script]
              env = [
                {
                  name  = "PGPASSWORD"
                  value = var.vault_postgres_password
                },
                {
                  name  = "PGHOST"
                  value = local.platform_pg_host
                },
                {
                  name  = "PGUSER"
                  value = "postgres"
                },
                {
                  name  = "PGPORT"
                  value = "5432"
                },
              ]
            }
          ]
        }
      }
    }
  })

  depends_on = [helm_release.platform_pg]
}

# Output for L2 to consume
output "platform_pg_host" {
  value       = local.platform_pg_host
  description = "Platform PostgreSQL service hostname"
}

output "platform_pg_port" {
  value       = 5432
  description = "Platform PostgreSQL service port"
}

output "platform_namespace" {
  value       = kubernetes_namespace.platform.metadata[0].name
  description = "Platform namespace name"
}
