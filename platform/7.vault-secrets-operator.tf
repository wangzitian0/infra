# Vault Secrets Operator (VSO)
# Purpose: Automatically sync Vault KV secrets to Kubernetes Secrets
#
# Architecture:
# - VSO watches VaultStaticSecret CRs in any namespace
# - Reads secrets from Vault KV using Kubernetes auth
# - Creates/updates K8s Secrets as specified in destination
#
# Flow: random_password → vault_kv_secret_v2 → VSO → K8s Secret → Helm existingSecret
#
# Reference: https://developer.hashicorp.com/vault/docs/platform/k8s/vso

resource "helm_release" "vault_secrets_operator" {
  name             = "vault-secrets-operator"
  namespace        = "vault-secrets-operator-system"
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault-secrets-operator"
  version          = "0.9.1"
  create_namespace = true
  timeout          = 300
  wait             = true
  wait_for_jobs    = true
  cleanup_on_fail  = true

  values = [
    yamlencode({
      # Default connection to Vault (used if VaultConnection CR not specified)
      defaultVaultConnection = {
        enabled = true
        address = "http://vault.platform.svc.cluster.local:8200"
      }
      controller = {
        manager = {
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
      }
    })
  ]

  depends_on = [helm_release.vault]

  lifecycle {
    postcondition {
      condition     = self.status == "deployed"
      error_message = "Vault Secrets Operator Helm release failed to deploy."
    }
  }
}

# Wait for VSO CRDs to be available before Data layer can create VaultStaticSecret CRs
resource "time_sleep" "wait_for_vso_crd" {
  create_duration = "30s"
  depends_on      = [helm_release.vault_secrets_operator]
}

output "vso_namespace" {
  value       = helm_release.vault_secrets_operator.namespace
  description = "Namespace where VSO is deployed"
}
