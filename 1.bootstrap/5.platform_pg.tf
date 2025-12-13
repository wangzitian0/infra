# L1.5: Platform PostgreSQL - Trust Anchor Database
# Purpose: Shared database for L2 platform services (Vault, Casdoor)
# Note: Deployed in L1 to avoid circular dependency with Vault
#
# Why L1?
# - Vault needs DB → Services need Vault → Can't use Vault to manage Vault's DB
# - This breaks SSOT intentionally as Trust Anchor
#
# Why native K8s instead of Helm?
# - Bitnami deletes old image tags (breaks reproducibility)
# - Official postgres image has stable tags
# - Full control over configuration
#
# Consumers:
# - Vault (L2): storage backend
# - Casdoor (L2): user/session data

# Create/manage platform namespace in L1 (before L2 Vault deployment)
resource "kubernetes_namespace" "platform" {
  metadata {
    name = "platform"
    labels = {
      layer = "L2"
    }
  }
}

# PostgreSQL Secret (password)
resource "kubernetes_secret" "platform_pg" {
  metadata {
    name      = "postgresql"
    namespace = kubernetes_namespace.platform.metadata[0].name
  }

  data = {
    POSTGRES_PASSWORD = var.vault_postgres_password
  }
}

# PostgreSQL Headless Service (for StatefulSet)
resource "kubernetes_service" "platform_pg_headless" {
  metadata {
    name      = "postgresql-hl"
    namespace = kubernetes_namespace.platform.metadata[0].name
    labels = {
      app = "postgresql"
    }
  }

  spec {
    type       = "ClusterIP"
    cluster_ip = "None"

    port {
      name        = "tcp-postgresql"
      port        = 5432
      target_port = 5432
    }

    selector = {
      app = "postgresql"
    }
  }
}

# PostgreSQL Service (for clients)
resource "kubernetes_service" "platform_pg" {
  metadata {
    name      = "postgresql"
    namespace = kubernetes_namespace.platform.metadata[0].name
    labels = {
      app = "postgresql"
    }
  }

  spec {
    type = "ClusterIP"

    port {
      name        = "tcp-postgresql"
      port        = 5432
      target_port = 5432
    }

    selector = {
      app = "postgresql"
    }
  }
}

# PostgreSQL StatefulSet
resource "kubernetes_stateful_set" "platform_pg" {
  metadata {
    name      = "postgresql"
    namespace = kubernetes_namespace.platform.metadata[0].name
    labels = {
      app = "postgresql"
    }
  }

  spec {
    service_name = kubernetes_service.platform_pg_headless.metadata[0].name
    replicas     = 1

    selector {
      match_labels = {
        app = "postgresql"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgresql"
        }
      }

      spec {
        container {
          name  = "postgresql"
          image = "postgres:17.2-alpine" # Official image, stable tags

          port {
            name           = "tcp-postgresql"
            container_port = 5432
          }

          env_from {
            secret_ref {
              name = kubernetes_secret.platform_pg.metadata[0].name
            }
          }

          env {
            name  = "POSTGRES_DB"
            value = "vault"
          }

          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          volume_mount {
            name       = "data"
            mount_path = "/var/lib/postgresql/data"
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres", "-d", "vault"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres", "-d", "vault"]
            }
            initial_delay_seconds = 5
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 6
          }
        }
      }
    }

    volume_claim_template {
      metadata {
        name = "data"
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = "local-path-retain"
        resources {
          requests = {
            storage = var.vault_postgres_storage
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.platform]
}

# Wait for PostgreSQL to be ready
resource "null_resource" "platform_pg_ready" {
  depends_on = [kubernetes_stateful_set.platform_pg]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = local.kubeconfig_path
    }
    command = <<-EOT
      echo "Waiting for PostgreSQL pod to be ready..."
      kubectl wait --for=condition=Ready pod/postgresql-0 -n platform --timeout=300s
    EOT
  }

  triggers = {
    statefulset_uid = kubernetes_stateful_set.platform_pg.metadata[0].uid
  }
}

# Vault PostgreSQL Schema
# Uses CREATE TABLE IF NOT EXISTS for idempotency
resource "null_resource" "vault_pg_schema" {
  depends_on = [null_resource.platform_pg_ready]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = local.kubeconfig_path
    }
    command = <<-EOT
      # Create Vault tables if they don't exist (idempotent)
      kubectl exec -n platform postgresql-0 -- psql -U postgres -d vault <<SQL
        -- Vault KV store table
        CREATE TABLE IF NOT EXISTS vault_kv_store (
          parent_path TEXT COLLATE "C" NOT NULL,
          path        TEXT COLLATE "C",
          key         TEXT COLLATE "C",
          value       BYTEA,
          CONSTRAINT pkey PRIMARY KEY (path, key)
        );
        CREATE INDEX IF NOT EXISTS parent_path_idx ON vault_kv_store (parent_path);

        -- Vault HA locks table
        CREATE TABLE IF NOT EXISTS vault_ha_locks (
          ha_key      TEXT COLLATE "C" NOT NULL,
          ha_identity TEXT COLLATE "C" NOT NULL,
          ha_value    TEXT COLLATE "C",
          valid_until TIMESTAMP WITH TIME ZONE NOT NULL,
          CONSTRAINT ha_key PRIMARY KEY (ha_key)
        );

        -- Verify tables exist
        SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE 'vault_%';
SQL
    EOT
  }

  triggers = {
    statefulset_uid = kubernetes_stateful_set.platform_pg.metadata[0].uid
  }
}

# Casdoor database - idempotent check-then-create pattern
resource "null_resource" "casdoor_database" {
  depends_on = [null_resource.platform_pg_ready]

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = local.kubeconfig_path
    }
    command = <<-EOT
      # Idempotent: check if database exists, create if not
      kubectl exec -n platform postgresql-0 -- psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = 'casdoor'" | grep -q 1 || \
      kubectl exec -n platform postgresql-0 -- psql -U postgres -c "CREATE DATABASE casdoor"
    EOT
  }

  triggers = {
    statefulset_uid = kubernetes_stateful_set.platform_pg.metadata[0].uid
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
