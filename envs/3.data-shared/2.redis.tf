# L3 Redis
#
# Purpose: Cache and session storage for L4 applications
#
# Architecture (after refactor - Issue #336):
# - L3 generates password locally
# - L3 stores password in Vault KV
# - L4 reads password from Vault KV
#
# Pattern: Bitnami Helm chart
# Namespace: per-env (data-staging, data-prod)
#
# Note: Redis doesn't have a Vault Database Engine equivalent
# so we just store the password in Vault KV for L4 to consume

# =============================================================================
# Password Generation (generated in L3, stored in Vault)
# =============================================================================

resource "random_password" "redis" {
  length  = 32
  special = false
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
        password = random_password.redis.result
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

  depends_on = [kubernetes_namespace.data]
}

# =============================================================================
# Vault KV Storage
# =============================================================================

resource "vault_kv_secret_v2" "redis" {
  mount               = data.terraform_remote_state.l2_platform.outputs.vault_kv_mount
  name                = data.terraform_remote_state.l2_platform.outputs.vault_db_secrets["redis"]
  delete_all_versions = true

  data_json = jsonencode({
    password = random_password.redis.result
    host     = "${helm_release.redis.name}-master.${local.namespace_name}.svc.cluster.local"
    port     = "6379"
  })

  depends_on = [helm_release.redis]
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
  value       = "${data.terraform_remote_state.l2_platform.outputs.vault_kv_mount}/data/${data.terraform_remote_state.l2_platform.outputs.vault_db_secrets["redis"]}"
  description = "Vault KV path for Redis credentials"
}
