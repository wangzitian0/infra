# =============================================================================
# Vault Config SSOT Module (Issue #301)
# Single Source of Truth for all Vault paths
# =============================================================================
module "vault_config" {
  source = "../modules/vault-config"
}

# =============================================================================
# Local Values
# =============================================================================
locals {
  # Namespace follows Atlantis workspace name (e.g., data-staging, data-prod)
  namespace_name = kubernetes_namespace.data.metadata[0].name
}
