# L3 Redis
#
# Purpose: Cache and session storage for L4 applications
# Password: Read from Vault KV at secret/data/redis (generated in L2)
# Pattern: Bitnami Helm chart (matches L1/L3 PostgreSQL pattern)
# Namespace: per-env (data-staging, data-prod)
#
# Architecture:
# L2 generates password → stores in Vault KV
# L3 reads password from Vault KV → deploys Redis
#
# Scalability:
# Current: Master-only (replica.replicaCount = 0)
# Future: Enable replicas for read scaling (see implementation_plan.md)

# =============================================================================
# Read Password from Vault (generated and stored by L2)
# Requires: TF_VAR_vault_root_token set in Atlantis Pod env
# =============================================================================

# SSOT Reference: Mount and name defined in 2.platform/locals.tf (vault_db_secrets)
data "vault_kv_secret_v2" "redis" {
  mount = "secret" # Must match 2.platform/locals.tf: vault_kv_mount
  name  = "redis"  # Must match 2.platform/locals.tf: vault_db_secrets["redis"]
}

# =============================================================================
# Redis via Bitnami Helm chart
# =============================================================================

resource "helm_release" "redis" {
  name             = "redis"
  namespace        = local.namespace_name # Per-env: data-staging, data-prod
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "redis"
  version          = "20.6.0"
  create_namespace = false
  timeout          = 300 # Consistent with PR #170 standard
  wait             = true
  wait_for_jobs    = true

  lifecycle {
    prevent_destroy = true # Prevent accidental data loss

    precondition {
      condition     = can(data.vault_kv_secret_v2.redis.data["password"]) && length(data.vault_kv_secret_v2.redis.data["password"]) >= 16
      error_message = "Redis password must be available in Vault KV and at least 16 characters."
    }

    postcondition {
      condition     = self.status == "deployed"
      error_message = "Redis Helm release failed to deploy. Check pod logs and events."
    }
  }

  values = [
    yamlencode({
      # Bitnami deletes old tags; use latest + IfNotPresent to reduce drift
      image = {
        tag        = "latest"
        pullPolicy = "IfNotPresent"
      }
      auth = {
        password = data.vault_kv_secret_v2.redis.data["password"]
      }
      master = {
        persistence = {
          enabled      = true
          storageClass = "local-path-retain"
          size         = "2Gi"
        }
        # Enhanced persistence configuration
        configuration = <<-EOT
          appendonly yes
          appendfsync everysec
          save 900 1
          save 300 10
          save 60 10000
        EOT
        resources = {
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
        }
      }
      replica = {
        replicaCount = 0 # Single VPS MVP: no replicas (can scale later)
      }
    })
  ]
}

# =============================================================================
# Outputs (Dynamic - follows namespace and release name)
# =============================================================================

output "redis_host" {
  value       = "${helm_release.redis.name}-master.${local.namespace_name}.svc.cluster.local"
  description = "Redis K8s service DNS for L4 applications"
}

output "redis_port" {
  value       = "6379"
  description = "Redis service port"
}

output "redis_vault_path" {
  value       = "secret/data/redis" # SSOT: 2.platform/locals.tf vault_secret_paths
  description = "Vault KV path for Redis credentials (see 2.platform/locals.tf)"
}

