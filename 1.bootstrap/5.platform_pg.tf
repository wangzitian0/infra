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
# - Casdoor (L2, future): user/session data



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
resource "helm_release" "platform_pg" {
  name             = "postgresql"
  namespace        = kubernetes_namespace.platform.metadata[0].name
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "postgresql"
  version          = "16.3.2"
  create_namespace = false
  timeout          = 300
  wait             = true
  wait_for_jobs    = true

  values = [
    yamlencode({
      # Bitnami only publishes "latest" tag reliably
      # Version-specific tags (e.g., 17.2.0-debian-12-r3) are often missing
      image = {
        tag = "latest"
      }
      auth = {
        postgresPassword = var.vault_postgres_password
        database         = "vault"
      }
      primary = {
        # Initialize databases on first startup (IaC pattern - no null_resource needed)
        initdb = {
          scripts = {
            "00-create-databases.sql" = <<-SQL
              -- Create Casdoor database if not exists
              SELECT 'CREATE DATABASE casdoor' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'casdoor')\gexec
              
              -- Grant permissions
              GRANT ALL PRIVILEGES ON DATABASE vault TO postgres;
              GRANT ALL PRIVILEGES ON DATABASE casdoor TO postgres;
            SQL
          }
        }
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
      # Disable metrics for now (can enable later for observability)
      metrics = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_namespace.platform]
}

# Vault PostgreSQL Schema
# Uses CREATE TABLE IF NOT EXISTS for idempotency
# NOTE: Must run in L1 (CI runner has kubectl), not L2 (Atlantis pod lacks kubectl)
resource "null_resource" "vault_pg_schema" {
  depends_on = [helm_release.platform_pg]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = local.kubeconfig_path
    }
    command = <<-EOT
      # Wait for PostgreSQL to be ready
      sleep 10

      # Create Vault tables if they don't exist (idempotent)
      kubectl exec -n platform postgresql-0 -- bash -c "
        PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres -d vault <<SQL
          -- Vault KV store table
          CREATE TABLE IF NOT EXISTS vault_kv_store (
            parent_path TEXT COLLATE \"C\" NOT NULL,
            path        TEXT COLLATE \"C\",
            key         TEXT COLLATE \"C\",
            value       BYTEA,
            CONSTRAINT pkey PRIMARY KEY (path, key)
          );
          CREATE INDEX IF NOT EXISTS parent_path_idx ON vault_kv_store (parent_path);

          -- Vault HA locks table
          CREATE TABLE IF NOT EXISTS vault_ha_locks (
            ha_key      TEXT COLLATE \"C\" NOT NULL,
            ha_identity TEXT COLLATE \"C\" NOT NULL,
            ha_value    TEXT COLLATE \"C\",
            valid_until TIMESTAMP WITH TIME ZONE NOT NULL,
            CONSTRAINT ha_key PRIMARY KEY (ha_key)
          );

          -- Verify tables exist
          SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE 'vault_%';
SQL
      " || true
    EOT
  }

  # Only re-run if PostgreSQL release changes (new deployment)
  triggers = {
    pg_release_revision = helm_release.platform_pg.metadata[0].revision
  }
}

# Casdoor database - separate resource to ensure it runs on first deploy
# This allows Casdoor to be enabled in L2 without waiting for L1 PostgreSQL changes
resource "null_resource" "casdoor_database" {
  depends_on = [helm_release.platform_pg]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = local.kubeconfig_path
    }
    command = <<-EOT
      # Wait for PostgreSQL to be ready
      sleep 10

      # Create Casdoor database if not exists (idempotent)
      kubectl exec -n platform postgresql-0 -- bash -c "
        PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres -tc \"SELECT 1 FROM pg_database WHERE datname = 'casdoor'\" | grep -q 1 || \
        PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres -c \"CREATE DATABASE casdoor\"
      " || true
    EOT
  }

  # Fixed trigger - runs once, then never again
  triggers = {
    casdoor_enabled = "true"
  }
}

# Output for L2 to consume
output "platform_pg_host" {
  value       = "postgresql.platform.svc.cluster.local"
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
