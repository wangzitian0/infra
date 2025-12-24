# Platform PostgreSQL - Trust Anchor Database via CloudNativePG
# Purpose: Shared database for Platform services (Vault, Casdoor)
# Note: Deployed in Bootstrap to avoid circular dependency with Vault
#
# Why Bootstrap?
# - Vault needs DB → Services need Vault → Can't use Vault to manage Vault's DB
# - This breaks SSOT intentionally as Trust Anchor
#
# Consumers:
# - Vault (Platform layer): storage backend
# - Casdoor (Platform layer): user/session data
#
# Pattern: CloudNativePG Cluster CR (professional operator)
# Docs: https://cloudnative-pg.io

# No local locals needed here, moved to centralized locals.tf

# Create/manage platform namespace in Bootstrap (before Platform layer Vault deployment)
resource "kubernetes_namespace" "platform" {
  metadata {
    name = local.k8s.ns_platform
    labels = {
      layer = "Platform"
    }
  }
}

# Superuser secret for CNPG (must exist before Cluster)
resource "kubernetes_secret" "platform_pg_superuser" {
  metadata {
    name      = "platform-pg-superuser"
    namespace = kubernetes_namespace.platform.metadata[0].name
  }

  data = {
    username = "postgres"
    password = var.vault_postgres_password
  }

  depends_on = [kubernetes_namespace.platform]

  lifecycle {
    precondition {
      condition     = length(var.vault_postgres_password) >= 16
      error_message = "vault_postgres_password must be at least 16 characters."
    }
  }
}

# Platform PostgreSQL via CloudNativePG Cluster
resource "kubectl_manifest" "platform_pg" {
  yaml_body = yamlencode({
    apiVersion = "postgresql.cnpg.io/v1"
    kind       = "Cluster"
    metadata = {
      name      = local.k8s.platform_pg_name
      namespace = kubernetes_namespace.platform.metadata[0].name
      labels = {
        layer = "Platform"
      }
    }
    spec = {
      # Single instance for platform services
      instances = 1

      # Bootstrap with Vault and Casdoor databases
      bootstrap = {
        initdb = {
          database = "vault"
          owner    = "postgres"
          postInitSQL = [
            # Idempotent: create Casdoor database
            "CREATE DATABASE casdoor;",
            # Digger orchestrator database
            "CREATE DATABASE digger;",
            # Vault tables (CNPG handles schema creation)
            "CREATE TABLE IF NOT EXISTS vault_kv_store (parent_path TEXT COLLATE \"C\" NOT NULL, path TEXT COLLATE \"C\", key TEXT COLLATE \"C\", value BYTEA, CONSTRAINT pkey PRIMARY KEY (path, key));",
            "CREATE INDEX IF NOT EXISTS parent_path_idx ON vault_kv_store (parent_path);",
            "CREATE TABLE IF NOT EXISTS vault_ha_locks (ha_key TEXT COLLATE \"C\" NOT NULL, ha_identity TEXT COLLATE \"C\" NOT NULL, ha_value TEXT COLLATE \"C\", valid_until TIMESTAMP WITH TIME ZONE NOT NULL, CONSTRAINT ha_key PRIMARY KEY (ha_key));"
          ]
        }
      }

      # Superuser credentials from K8s secret
      superuserSecret = {
        name = "platform-pg-superuser"
      }

      # Storage configuration
      storage = {
        storageClass = "local-path-retain"
        size         = var.vault_postgres_storage
      }

      # Resource limits
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

      # PostgreSQL configuration
      postgresql = {
        parameters = {
          shared_buffers       = "128MB"
          max_connections      = "100"
          effective_cache_size = "256MB"
          wal_level            = "replica"
        }
      }

      # Monitoring (disabled for now)
      monitoring = {
        enablePodMonitor = false
      }
    }
  })

  # CNPG operator must be installed first to have the CRD available
  depends_on = [kubernetes_secret.platform_pg_superuser, helm_release.cnpg_operator]
}

# Wait for CNPG cluster to be ready before Platform layer services connect
resource "time_sleep" "wait_for_platform_pg" {
  create_duration = "60s"
  depends_on      = [kubectl_manifest.platform_pg]

  lifecycle {
    postcondition {
      condition     = strcontains(local.k8s.platform_pg_host, "svc.cluster.local")
      error_message = "platform_pg_host must follow standard K8s internal DNS pattern."
    }
  }
}

# Output for Platform layer to consume
output "platform_pg_host" {
  value       = local.k8s.platform_pg_host
  description = "Platform PostgreSQL service hostname (CNPG read-write service)"
}

output "platform_pg_port" {
  value       = 5432
  description = "Platform PostgreSQL service port"
}

output "platform_namespace" {
  value       = kubernetes_namespace.platform.metadata[0].name
  description = "Platform namespace name"
}

output "platform_pg_ready" {
  value       = true
  description = "Platform PostgreSQL cluster is ready for connections"
  depends_on  = [time_sleep.wait_for_platform_pg]
}


