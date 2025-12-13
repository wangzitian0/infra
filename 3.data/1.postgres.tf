# L3 Business PostgreSQL
#
# Purpose: PostgreSQL for business applications (L4)
# Password: Read from Vault KV at secret/data/postgres (generated in L2)
#
# Pattern: Bitnami Helm chart (matches L1 platform_pg)
# Note: Bitnami deletes old image tags, so we use 'latest' with IfNotPresent
#
# Consumers:
# - L4 Apps: business data storage
# - L2 Vault: dynamic credential generation
#
# Namespace: singular 'data' (not per-env) because:
# - L2 Vault database engine is singleton, expects postgresql.data.svc
# - Single VPS MVP doesn't need DB-level env isolation
# - L4 apps handle env isolation at app layer

# =============================================================================
# Namespace (singular 'data' - L2 Vault connection expects this)
# =============================================================================

resource "kubernetes_namespace" "data" {
  metadata {
    name = "data"
    labels = {
      layer = "L3"
    }
  }
}

# =============================================================================
# Read Password from Vault (generated and stored by L2)
# Note: Only reads when vault_root_token is provided; uses dummy for plan
# =============================================================================

locals {
  # Check if vault token is available (non-empty)
  vault_token_available = var.vault_root_token != ""
}

data "vault_kv_secret_v2" "postgres" {
  count = local.vault_token_available ? 1 : 0
  mount = "secret"
  name  = "data/postgres"
}

locals {
  # Use Vault password if available, dummy for plan-time
  postgres_password = local.vault_token_available ? data.vault_kv_secret_v2.postgres[0].data["password"] : "plan-time-dummy-will-be-replaced-at-apply"
}

# =============================================================================
# PostgreSQL via Bitnami Helm chart (matches L1 pattern)
# =============================================================================

resource "helm_release" "postgresql" {
  name             = "postgresql"
  namespace        = kubernetes_namespace.data.metadata[0].name
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "postgresql"
  version          = "16.4.2"
  create_namespace = false
  timeout          = 300
  wait             = true
  wait_for_jobs    = true

  values = [
    yamlencode({
      # Bitnami deletes old tags; use latest + IfNotPresent to reduce drift
      image = {
        tag        = "latest"
        pullPolicy = "IfNotPresent"
      }
      auth = {
        postgresPassword = local.postgres_password
        database         = "app"
      }
      primary = {
        persistence = {
          enabled      = true
          storageClass = "local-path-retain"
          size         = "10Gi"
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
    })
  ]

  # Prevent apply with dummy password
  lifecycle {
    precondition {
      condition     = local.vault_token_available
      error_message = "vault_root_token must be set to apply. Provide via TF_VAR_vault_root_token."
    }
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "postgres_host" {
  value       = "postgresql.data.svc.cluster.local"
  description = "PostgreSQL K8s service DNS"
}

output "postgres_vault_path" {
  value       = "secret/data/postgres"
  description = "Vault KV path for PostgreSQL credentials"
}

output "postgres_namespace" {
  value       = "data"
  description = "Namespace where PostgreSQL is deployed"
}
