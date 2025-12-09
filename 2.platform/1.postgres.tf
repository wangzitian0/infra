# Platform PostgreSQL (Vault storage backend)
# Namespace: platform (L2)
# Storage: local-path PVC (Retain)

resource "kubernetes_namespace" "platform" {
  metadata {
    name = "platform"
    labels = {
      layer = "L2"
    }
  }
}

resource "helm_release" "postgresql" {
  name      = "postgresql"
  namespace = kubernetes_namespace.platform.metadata[0].name

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "15.5.0"

  values = [
    yamlencode({
      image = {
        tag = "latest"
      }
      auth = {
        username = "vault"
        password = var.vault_postgres_password
        database = "vault"
      }
      primary = {
        persistence = {
          enabled      = true
          size         = var.vault_postgres_storage
          storageClass = "local-path-retain"
        }
        resources = {
          limits = {
            cpu    = "500m"
            memory = "1Gi"
          }
          requests = {
            cpu    = "250m"
            memory = "512Mi"
          }
        }
      }
      readReplicas = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_namespace.platform]
}

output "postgresql_endpoint" {
  value = "postgresql.${kubernetes_namespace.platform.metadata[0].name}.svc.cluster.local:5432"
}

output "postgresql_database" {
  value = "vault"
}

output "postgresql_user" {
  value = "vault"
}
