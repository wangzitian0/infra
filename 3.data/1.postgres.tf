# L3 Business PostgreSQL
#
# Purpose: PostgreSQL for business applications (L4)
# Password: Read from Vault KV at secret/data/postgres (generated in L2)
#
# Why native K8s instead of Helm?
# - Bitnami deletes old image tags (breaks reproducibility)
# - Official postgres image has stable tags
# - Consistent with L1 platform_pg pattern
#
# Consumers:
# - L4 Apps: business data storage
# - L2 Vault: dynamic credential generation

# =============================================================================
# Namespace (SSOT: docs/ssot/env.md - L3 uses data-<env>)
# =============================================================================

resource "kubernetes_namespace" "data" {
  metadata {
    name = "data-${var.environment}"
    labels = {
      layer       = "L3"
      environment = var.environment
    }
  }
}

# =============================================================================
# Read Password from Vault (generated and stored by L2)
# =============================================================================

data "vault_kv_secret_v2" "postgres" {
  mount = "secret"
  name  = "data/postgres"
}

# =============================================================================
# PostgreSQL Secret
# =============================================================================

resource "kubernetes_secret" "postgres" {
  metadata {
    name      = "postgresql"
    namespace = kubernetes_namespace.data.metadata[0].name
  }

  data = {
    POSTGRES_PASSWORD = data.vault_kv_secret_v2.postgres.data["password"]
  }
}

# =============================================================================
# PostgreSQL Headless Service (for StatefulSet)
# =============================================================================

resource "kubernetes_service" "postgres_headless" {
  metadata {
    name      = "postgresql-hl"
    namespace = kubernetes_namespace.data.metadata[0].name
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

# =============================================================================
# PostgreSQL Service (for clients)
# =============================================================================

resource "kubernetes_service" "postgres" {
  metadata {
    name      = "postgresql"
    namespace = kubernetes_namespace.data.metadata[0].name
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

# =============================================================================
# PostgreSQL StatefulSet (matching L1 pattern)
# =============================================================================

resource "kubernetes_stateful_set" "postgres" {
  metadata {
    name      = "postgresql"
    namespace = kubernetes_namespace.data.metadata[0].name
    labels = {
      app = "postgresql"
    }
  }

  spec {
    service_name = kubernetes_service.postgres_headless.metadata[0].name
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
          image = "postgres:17.2-alpine" # Official image, stable tags (matches L1)

          port {
            name           = "tcp-postgresql"
            container_port = 5432
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }

          env {
            name  = "POSTGRES_USER"
            value = "postgres"
          }

          env {
            name  = "POSTGRES_DB"
            value = "app"
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
            requests = {
              cpu    = "100m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres"]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
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
            storage = "10Gi"
          }
        }
      }
    }
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "postgres_host" {
  value       = "postgresql.data-${var.environment}.svc.cluster.local"
  description = "PostgreSQL K8s service DNS"
}

output "postgres_vault_path" {
  value       = "secret/data/postgres"
  description = "Vault KV path for PostgreSQL credentials"
}

output "postgres_namespace" {
  value       = "data-${var.environment}"
  description = "Namespace where PostgreSQL is deployed"
}
