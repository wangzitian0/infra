# Purpose: Cache and session storage for applications

#
# Architecture (VSO Pattern - Issue #351):
# - random_password generates password on first deploy
# - vault_kv_secret_v2 stores password in Vault (SSOT)
# - VaultStaticSecret syncs Vault → K8s Secret (via VSO)
# - Helm uses existingSecret to read from K8s Secret
#
# Pattern: Opstree Redis Operator + Redis CR (standalone)
# Namespace: per-env (data-staging, data-prod)
#
# Note: Redis doesn't have a Vault Database Engine equivalent
# so we just store the password in Vault KV for L4 to consume

# =============================================================================
# Password Management (VSO Pattern - Issue #351)
# =============================================================================

resource "random_password" "redis" {
  length  = 32
  special = false
}

# =============================================================================
# Vault KV Storage (store password - SSOT)
# =============================================================================

resource "vault_kv_secret_v2" "redis" {
  mount               = data.terraform_remote_state.platform.outputs.vault_kv_mount
  name                = data.terraform_remote_state.platform.outputs.vault_db_secrets["redis"]
  delete_all_versions = true

  data_json = jsonencode({
    password = random_password.redis.result
    host     = "redis-master.${local.namespace_name}.svc.cluster.local"
    port     = "6379"
  })

  depends_on = [kubernetes_namespace.data]

  lifecycle {
    # Don't overwrite existing password in Vault during state recovery
    ignore_changes = [data_json]
  }
}

# =============================================================================
# VaultStaticSecret - Syncs Vault KV → K8s Secret (via VSO)
# =============================================================================

resource "kubectl_manifest" "redis_vault_secret" {
  yaml_body = yamlencode({
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultStaticSecret"
    metadata = {
      name      = "redis-credentials"
      namespace = local.namespace_name
    }
    spec = {
      type  = "kv-v2"
      mount = data.terraform_remote_state.platform.outputs.vault_kv_mount
      path  = data.terraform_remote_state.platform.outputs.vault_db_secrets["redis"]
      destination = {
        name   = "redis-credentials"
        create = true
      }
      refreshAfter = "1h"
      vaultAuthRef = "default"
    }
  })

  depends_on = [vault_kv_secret_v2.redis, kubectl_manifest.vault_auth]
}

# Wait for VSO to sync the secret before Helm tries to use it
resource "time_sleep" "wait_for_redis_secret" {
  create_duration = "15s"
  depends_on      = [kubectl_manifest.redis_vault_secret]
}

# =============================================================================
# Redis Operator (Opstree)
# =============================================================================

resource "helm_release" "redis_operator" {
  name             = "redis-operator"
  namespace        = local.namespace_name # Per-env: data-staging, data-prod
  repository       = "https://ot-container-kit.github.io/helm-charts/"
  chart            = "redis-operator"
  version          = "0.6.0"
  create_namespace = false
  timeout          = 300 # Consistent with PR #170 standard
  wait             = true
  wait_for_jobs    = true

  lifecycle {
    postcondition {
      condition     = self.status == "deployed"
      error_message = "Redis operator Helm release failed to deploy. Check pod logs and events."
    }
  }

  depends_on = [kubernetes_namespace.data]
}

# Wait for Redis Operator CRD to be established
resource "time_sleep" "wait_for_redis_crd" {
  create_duration = "30s"

  depends_on = [helm_release.redis_operator]
}

# =============================================================================
# Redis Standalone CR
# =============================================================================

resource "kubectl_manifest" "redis" {
  yaml_body = yamlencode({
    apiVersion = "redis.redis.opstreelabs.in/v1beta2"
    kind       = "Redis"
    metadata = {
      name      = "redis-master"
      namespace = local.namespace_name
      labels = {
        module = "data"
        env    = local.env_name
      }
    }
    spec = {
      kubernetesConfig = {
        image           = "quay.io/opstree/redis:v7.0.15"
        imagePullPolicy = "IfNotPresent"
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
        redisSecret = {
          name = "redis-credentials"
          key  = "password"
        }
        service = {
          additional = {
            enabled = false
          }
        }
      }
      redisConfig = {
        additionalRedisConfig = <<-EOT
          appendonly yes
          appendfsync everysec
          save 900 1
          save 300 10
          save 60 10000
        EOT
      }
      storage = {
        keepAfterDelete = true
        volumeClaimTemplate = {
          spec = {
            storageClassName = "local-path-retain"
            accessModes      = ["ReadWriteOnce"]
            resources = {
              requests = {
                storage = "2Gi"
              }
            }
          }
        }
      }
    }
  })

  depends_on = [
    time_sleep.wait_for_redis_secret,
    time_sleep.wait_for_redis_crd
  ]
}

# =============================================================================
# Outputs (Dynamic - follows namespace and release name)
# =============================================================================

output "redis_host" {
  value       = "redis-master.${local.namespace_name}.svc.cluster.local"
  description = "Redis K8s service DNS for L4 applications"
}

output "redis_port" {
  value       = "6379"
  description = "Redis service port"
}

output "redis_vault_path" {
  value       = "${data.terraform_remote_state.platform.outputs.vault_kv_mount}/data/${data.terraform_remote_state.platform.outputs.vault_db_secrets["redis"]}"
  description = "Vault KV path for Redis credentials"
}
