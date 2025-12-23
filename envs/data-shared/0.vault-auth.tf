# =============================================================================
# VaultAuth CR for Vault Secrets Operator (VSO)
# Purpose: Enable VSO to authenticate with Vault using Kubernetes auth
#
# This creates a VaultAuth resource that VSO uses to authenticate to Vault.
# Each VaultStaticSecret references this auth to read from Vault KV.
#
# Flow: VSO → VaultAuth → Vault Kubernetes Auth → secret/data/* → K8s Secret
# =============================================================================

# Wait for VSO CRDs to be available (deployed by Platform)
# This ensures kubectl_manifest can validate VaultAuth CRD exists
resource "time_sleep" "wait_for_vso" {
  create_duration = "10s"
  depends_on      = [kubernetes_namespace.data]
}

# VaultAuth CR - tells VSO how to authenticate with Vault
resource "kubectl_manifest" "vault_auth" {
  yaml_body = yamlencode({
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultAuth"
    metadata = {
      name      = "default"
      namespace = local.namespace_name
    }
    spec = {
      method = "kubernetes"
      mount  = "kubernetes"
      kubernetes = {
        role           = "vault-secrets-operator"
        serviceAccount = "default"
        audiences      = ["vault"]
      }
    }
  })

  depends_on = [time_sleep.wait_for_vso]
}
