# Phase 1.1: PostgreSQL (Infisical DB)
# Namespace: iac
# Storage: local-path PVC

resource "kubernetes_namespace" "iac" {
  metadata {
    name = var.namespaces["iac"]
  }
}

resource "helm_release" "postgresql" {
  name      = "postgresql"
  namespace = kubernetes_namespace.iac.metadata[0].name

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "13.1.0"

  values = [
    yamlencode({
      image = {
        tag = "16-debian-12" # Stable rolling tag for PG 16
      }
      auth = {
        username = "infisical"
        password = var.infisical_postgres_password
        database = "infisical"
      }
      primary = {
        persistence = {
          enabled      = true
          size         = var.infisical_postgres_storage
          storageClass = "local-path"
        }
        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
        }
      }
      readReplicas = {
        enabled = false
      }
    })
  ]

  depends_on = [kubernetes_namespace.iac]
}

output "postgresql_endpoint" {
  value = "postgresql.${kubernetes_namespace.iac.metadata[0].name}.svc.cluster.local:5432"
}

output "postgresql_database" {
  value = "infisical"
}

output "postgresql_user" {
  value = "infisical"
}
