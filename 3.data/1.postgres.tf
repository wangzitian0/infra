# L3 Business PostgreSQL
#
# Purpose: PostgreSQL for business applications (L4)
# Password: Stored in Vault KV at secret/data/postgres

# =============================================================================
# Namespace
# =============================================================================

resource "kubernetes_namespace" "data" {
  metadata {
    name = "data"
  }
}

# =============================================================================
# Password Generation
# =============================================================================

resource "random_password" "postgres" {
  length  = 24
  special = false
}

# =============================================================================
# Store Password in Vault
# =============================================================================

resource "vault_kv_secret_v2" "postgres" {
  mount = "secret"
  name  = "data/postgres"

  data_json = jsonencode({
    username = "postgres"
    password = random_password.postgres.result
    host     = "postgresql.data.svc.cluster.local"
    port     = "5432"
    database = "app"
  })
}

# =============================================================================
# PostgreSQL Helm Release
# =============================================================================

resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "oci://registry-1.docker.io/bitnamicharts"
  chart      = "postgresql"
  version    = "16.3.2"
  namespace  = kubernetes_namespace.data.metadata[0].name
  timeout    = 300

  values = [
    yamlencode({
      auth = {
        postgresPassword = random_password.postgres.result
        database         = "app"
      }
      primary = {
        persistence = {
          storageClass = "local-path-retain"
          size         = "10Gi"
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }
      image = {
        tag = "16.1.0-debian-12-r10"
      }
    })
  ]
}

# =============================================================================
# Outputs
# =============================================================================

output "postgres_vault_path" {
  value       = "secret/data/postgres"
  description = "Vault KV path for PostgreSQL credentials"
}

output "postgres_host" {
  value       = "postgresql.data.svc.cluster.local"
  description = "PostgreSQL K8s service DNS"
}
