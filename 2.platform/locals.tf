locals {
  internal_domain         = var.internal_domain != "" ? var.internal_domain : var.base_domain
  portal_sso_gate_enabled = var.enable_portal_sso_gate
  # Vault resources only created when vault_root_token is provided
  # This allows CI to skip Vault config when Vault is unreachable
  # Use nonsensitive() to avoid tainting outputs as sensitive
  vault_enabled = nonsensitive(var.vault_root_token) != ""
}

# =============================================================================
# Vault Config SSOT Module (Issue #301)
# Single Source of Truth for all Vault paths
# =============================================================================
module "vault_config" {
  source = "../modules/vault-config"
}
