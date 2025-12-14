# L3 ArangoDB
#
# Purpose: Multi-model database (document, graph, key-value) for L4 applications
# Password: Read from Vault KV at secret/data/arangodb (generated in L2)
# Pattern: ArangoDB official Operator + Custom Resource
# Namespace: per-env (data-staging, data-prod)
#
# Architecture:
# L2 generates password → stores in Vault KV
# L3 reads password from Vault KV → deploys ArangoDB Operator → creates ArangoDeployment CR
#
# Scalability:
# Current: Single mode (single.count=1)
# Future: Cluster mode (3 Agents + 2 Coordinators + 2 DBServers, see implementation_plan.md)
# Note: Migrating from Single to Cluster requires data migration (cannot hot-upgrade)

# =============================================================================
# Read Password from Vault (generated and stored by L2)
# Requires: TF_VAR_vault_root_token set in Atlantis Pod env
# =============================================================================

data "vault_kv_secret_v2" "arangodb" {
  mount = "secret"
  name  = "data/arangodb"
}

# =============================================================================
# ArangoDB Operator (kube-arangodb)
# Must be deployed before creating ArangoDeployment CR
# =============================================================================

resource "helm_release" "arangodb_operator" {
  name             = "arangodb-operator"
  namespace        = local.namespace_name  # Per-env: data-staging, data-prod
  repository       = "https://arangodb.github.io/kube-arangodb"
  chart            = "kube-arangodb"
  version          = "1.2.43"
  create_namespace = false
  timeout          = 300  # Consistent with PR #170 standard
  wait             = true
  wait_for_jobs    = true

  lifecycle {
    prevent_destroy = true  # Prevent accidental deletion

    precondition {
      condition     = can(data.vault_kv_secret_v2.arangodb.data["password"]) && length(data.vault_kv_secret_v2.arangodb.data["password"]) >= 16
      error_message = "ArangoDB password must be available in Vault KV and at least 16 characters."
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

# =============================================================================
# JWT Secret for ArangoDB Authentication
# ArangoDB requires a minimum 32-byte secret for JWT signing
# =============================================================================

# Generate secure JWT secret (not derived from password)
resource "random_bytes" "arangodb_jwt" {
  length = 32  # ArangoDB JWT requirement

  lifecycle {
    precondition {
      condition     = can(data.vault_kv_secret_v2.arangodb.data["password"])
      error_message = "ArangoDB password must be available in Vault before generating JWT secret."
    }
  }
}

resource "kubernetes_secret" "arangodb_jwt" {
  metadata {
    name      = "arangodb-jwt"
    namespace = local.namespace_name
  }

  data = {
    token = random_bytes.arangodb_jwt.base64
  }

  depends_on = [kubernetes_namespace.data]
}

# =============================================================================
# ArangoDB Deployment CR (Single Mode)
# Creates a single-server ArangoDB instance
# =============================================================================

resource "kubernetes_manifest" "arangodb_deployment" {
  manifest = {
    apiVersion = "database.arangodb.com/v1"
    kind       = "ArangoDeployment"
    metadata = {
      name      = "arangodb"
      namespace = kubernetes_namespace.data.metadata[0].name
    }
    spec = {
      mode  = "Single" # Single-server mode for MVP (migrate to Cluster later)
      image = "arangodb/arangodb:3.11.8"  # Fixed version (was latest)
      auth = {
        jwtSecretName = kubernetes_secret.arangodb_jwt.metadata[0].name
      }
      single = {
        count = 1 # Single instance
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
  }

  depends_on = [
    helm_release.arangodb_operator,
    kubernetes_secret.arangodb_jwt
  ]
}

# =============================================================================
# Outputs
# =============================================================================

output "arangodb_host" {
  value       = "${kubernetes_manifest.arangodb_deployment.manifest.metadata.name}.${local.namespace_name}.svc.cluster.local"
  description = "ArangoDB K8s service DNS for L4 applications"
}

output "arangodb_port" {
  value       = "8529"
  description = "ArangoDB HTTP API port"
}

output "arangodb_vault_path" {
  value       = "secret/data/arangodb"
  description = "Vault KV path for ArangoDB credentials"
}

output "arangodb_username" {
  value       = "root"
  description = "ArangoDB default username"
}
