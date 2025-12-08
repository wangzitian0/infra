# Phase 1.1: PostgreSQL (Infisical DB)
# Namespace: security
# Storage: local-path PVC

resource "kubernetes_namespace" "security" {
  metadata {
    name = var.namespaces["security"]
  }
}

resource "helm_release" "postgresql" {
  name      = "postgresql"
  namespace = kubernetes_namespace.security.metadata[0].name

  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "15.5.0"

  values = [
    yamlencode({
      image = {
        tag = "latest"
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

  depends_on = [kubernetes_namespace.security]
}

output "postgresql_endpoint" {
  value = "postgresql.${kubernetes_namespace.security.metadata[0].name}.svc.cluster.local:5432"
}

output "postgresql_database" {
  value = "infisical"
}

output "postgresql_user" {
  value = "infisical"
}
