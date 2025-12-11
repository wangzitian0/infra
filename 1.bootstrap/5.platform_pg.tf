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

# Create platform namespace in L1 (before L2 Vault deployment)
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
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "postgresql"
  version          = "16.3.3"
  create_namespace = false
  timeout          = 600

  values = [
    yamlencode({
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
      # Disable metrics for now (can enable later for observability)
      metrics = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_namespace.platform]
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
