# L3 ArangoDB
#
# Purpose: Multi-model database (document, graph, key-value) for L4 applications
#
# Architecture (VSO Pattern - Issue #351):
# - random_password generates password on first deploy
# - vault_kv_secret_v2 stores password + JWT in Vault (SSOT)
# - VaultStaticSecret syncs Vault → K8s Secret (via VSO)
# - ArangoDB Operator reads JWT from K8s Secret
#
# Pattern: ArangoDB official Operator + Custom Resource
# Namespace: per-env (data-staging, data-prod)
#
# Scalability:
# Current: Single mode (single.count=1)
# Future: Cluster mode (3 Agents + 2 Coordinators + 2 DBServers)
# Note: Migrating from Single to Cluster requires data migration (cannot hot-upgrade)

# =============================================================================
# Password Management (VSO Pattern - Issue #351)
# =============================================================================

resource "random_password" "arangodb" {
  length  = 32
  special = false
}

# Generate JWT secret for ArangoDB (32 bytes minimum)
resource "random_bytes" "arangodb_jwt" {
  length = 32
}

# =============================================================================
# Vault KV Storage (store password + JWT - SSOT)
# =============================================================================

resource "vault_kv_secret_v2" "arangodb" {
  mount               = data.terraform_remote_state.l2_platform.outputs.vault_kv_mount
  name                = data.terraform_remote_state.l2_platform.outputs.vault_db_secrets["arangodb"]
  delete_all_versions = true

  data_json = jsonencode({
    username   = "root"
    password   = random_password.arangodb.result
    jwt_secret = random_bytes.arangodb_jwt.base64
    token      = random_bytes.arangodb_jwt.base64 # Alias for JWT secret (VSO key)
    host       = "arangodb.${local.namespace_name}.svc.cluster.local"
    port       = "8529"
  })

  depends_on = [kubernetes_namespace.data]

  lifecycle {
    # Don't overwrite existing credentials in Vault during state recovery
    ignore_changes = [data_json]
  }
}

# =============================================================================
# VaultStaticSecret - Syncs Vault KV → K8s Secret (via VSO)
# =============================================================================

resource "kubectl_manifest" "arangodb_vault_secret" {
  yaml_body = yamlencode({
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultStaticSecret"
    metadata = {
      name      = "arangodb-credentials"
      namespace = local.namespace_name
    }
    spec = {
      type  = "kv-v2"
      mount = data.terraform_remote_state.l2_platform.outputs.vault_kv_mount
      path  = data.terraform_remote_state.l2_platform.outputs.vault_db_secrets["arangodb"]
      destination = {
        name   = "arangodb-credentials"
        create = true
      }
      refreshAfter = "1h"
      vaultAuthRef = "default"
    }
  })

  depends_on = [vault_kv_secret_v2.arangodb, kubectl_manifest.vault_auth]
}

# Wait for VSO to sync the secret before deploying ArangoDB
resource "time_sleep" "wait_for_arangodb_secret" {
  create_duration = "15s"
  depends_on      = [kubectl_manifest.arangodb_vault_secret]
}

# =============================================================================
# ArangoDB Operator (kube-arangodb)
# Must be deployed before creating ArangoDeployment CR
# =============================================================================

resource "helm_release" "arangodb_operator" {
  name             = "arangodb-operator"
  namespace        = local.namespace_name # Per-env: data-staging, data-prod
  repository       = "https://arangodb.github.io/kube-arangodb"
  chart            = "kube-arangodb"
  version          = "1.2.43"
  create_namespace = false
  timeout          = 300 # Consistent with PR #170 standard
  wait             = true
  wait_for_jobs    = true

  lifecycle {
    prevent_destroy = true # Prevent accidental deletion

    postcondition {
      condition     = self.status == "deployed"
      error_message = "ArangoDB operator Helm release failed to deploy. Check pod logs and events."
    }
  }

  values = [
    yamlencode({
      operator = {
        replicaCount = 1
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
    })
  ]

  depends_on = [kubernetes_namespace.data]
}

# Wait for ArangoDB Operator CRD to be established
# Helm wait=true only waits for Deployment ready, not CRD availability
resource "time_sleep" "wait_for_arangodb_crd" {
  create_duration = "30s"

  depends_on = [helm_release.arangodb_operator]
}

# =============================================================================
# ArangoDB Deployment CR (Single Mode)
# Creates a single-server ArangoDB instance
# Using kubectl_manifest to avoid plan-time CRD validation
# Note: Uses VSO-synced secret (arangodb-credentials) which contains 'token' key for JWT
# =============================================================================

resource "kubectl_manifest" "arangodb_deployment" {
  yaml_body = yamlencode({
    apiVersion = "database.arangodb.com/v1"
    kind       = "ArangoDeployment"
    metadata = {
      name      = "arangodb"
      namespace = kubernetes_namespace.data.metadata[0].name
    }
    spec = {
      mode  = "Single"
      image = "arangodb/arangodb:3.11.8"
      auth = {
        # Use VSO-synced secret which contains 'token' key for JWT
        jwtSecretName = "arangodb-credentials"
      }
      single = {
        count = 1
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
        volumeClaimTemplate = {
          spec = {
            storageClassName = "local-path-retain"
            accessModes      = ["ReadWriteOnce"]
            resources = {
              requests = {
                storage = "5Gi"
              }
            }
          }
        }
      }
    }
  })

  depends_on = [
    time_sleep.wait_for_arangodb_crd,
    time_sleep.wait_for_arangodb_secret
  ]
}

# =============================================================================
# Outputs
# =============================================================================

output "arangodb_host" {
  value       = "arangodb.${local.namespace_name}.svc.cluster.local"
  description = "ArangoDB K8s service DNS for L4 applications"
}

output "arangodb_port" {
  value       = "8529"
  description = "ArangoDB HTTP API port"
}

output "arangodb_vault_path" {
  value       = "${data.terraform_remote_state.l2_platform.outputs.vault_kv_mount}/data/${data.terraform_remote_state.l2_platform.outputs.vault_db_secrets["arangodb"]}"
  description = "Vault KV path for ArangoDB credentials"
}

output "arangodb_username" {
  value       = "root"
  description = "ArangoDB default username"
}
