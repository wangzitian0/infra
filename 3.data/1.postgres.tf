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
# - L2 Vault database engine connects to staging: postgresql.data-staging.svc
# - Single VPS MVP doesn't need DB-level env isolation
# - L4 apps handle env isolation at app layer
#
# Architecture:
# L2 generates password → stores in Vault KV
# L3 reads password from Vault KV → deploys PostgreSQL

# =============================================================================
# Namespace (per-environment: data-staging, data-prod)
# =============================================================================

locals {
  namespace_name = "data-${terraform.workspace}"
}

resource "kubernetes_namespace" "data" {
  metadata {
    name = local.namespace_name
    labels = {
      layer = "L3"
      env   = terraform.workspace
    }
  }
}

# =============================================================================
# Read Password from Vault (generated and stored by L2)
# Requires: TF_VAR_vault_root_token set in Atlantis Pod env
# =============================================================================

data "vault_kv_secret_v2" "postgres" {
  mount = "secret"
  name  = "data/postgres"
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
        postgresPassword = data.vault_kv_secret_v2.postgres.data["password"]
        database         = "app"
      }
      primary = {
        # Wait for Vault to be available (max 120s timeout)
        initContainers = [
          {
            name  = "wait-for-vault"
            image = "busybox:1.36"
            command = [
              "sh", "-c",
              "t=120;e=0;until nc -z vault.platform.svc.cluster.local 8200;do echo \"waiting for Vault... ($e/$t s)\";sleep 2;e=$((e+2));[ $e -ge $t ]&&exit 1;done"
            ]
          }
        ]
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

  lifecycle {
    precondition {
      condition     = can(data.vault_kv_secret_v2.postgres.data["password"]) && length(data.vault_kv_secret_v2.postgres.data["password"]) >= 16
      error_message = "L3 PostgreSQL password must be available in Vault KV and at least 16 characters."
    }
  }
}

# =============================================================================
# Outputs
# =============================================================================

output "postgres_host" {
  value       = "postgresql.${local.namespace_name}.svc.cluster.local"
  description = "PostgreSQL K8s service DNS"
}

output "postgres_vault_path" {
  value       = "secret/data/postgres"
  description = "Vault KV path for PostgreSQL credentials"
}

output "postgres_namespace" {
  value       = local.namespace_name
  description = "Namespace where PostgreSQL is deployed"
}
