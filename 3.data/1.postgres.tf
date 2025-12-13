# L3 Business PostgreSQL
#
# Purpose: PostgreSQL for business applications (L4)
# Password: Read from Vault KV at secret/data/postgres (generated in L2)

# =============================================================================
# Namespace (SSOT: docs/ssot/env.md - L3 uses data-<env>)
# =============================================================================

resource "kubernetes_namespace" "data" {
  metadata {
    name = "data-${var.environment}"
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
        postgresPassword = data.vault_kv_secret_v2.postgres.data["password"]
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
