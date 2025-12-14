# L3 Redis
#
# Purpose: Cache and session storage for L4 applications
# Password: Read from Vault KV at secret/data/redis (generated in L2)
# Pattern: Bitnami Helm chart (matches L1/L3 PostgreSQL pattern)
# Namespace: data (shared with PostgreSQL)
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

data "vault_kv_secret_v2" "redis" {
  mount = "secret"
  name  = "data/redis"
}

# =============================================================================
# Redis via Bitnami Helm chart
# =============================================================================

resource "helm_release" "redis" {
  name             = "redis"
  namespace        = kubernetes_namespace.data.metadata[0].name
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "redis"
  version          = "20.6.0"
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
        password = data.vault_kv_secret_v2.redis.data["password"]
      }
      master = {
        persistence = {
          enabled      = true
          storageClass = "local-path-retain"
          size         = "2Gi"
        }
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
# Outputs
# =============================================================================

output "redis_host" {
  value       = "redis-master.data.svc.cluster.local"
  description = "Redis K8s service DNS for L4 applications"
}

output "redis_port" {
  value       = "6379"
  description = "Redis service port"
}

output "redis_vault_path" {
  value       = "secret/data/redis"
  description = "Vault KV path for Redis credentials"
}
