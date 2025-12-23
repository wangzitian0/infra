# Casdoor Roles Management via RestAPI Provider
# Defines role-based access control for Vault and other services
#
# Resources:
# - vault-admin: Full administrative access to Vault
# - vault-developer: Read/write access to application secrets
# - vault-viewer: Read-only access to Vault

# =============================================================================
# Local Variables for User Assignment
# =============================================================================

locals {
  # Construct Casdoor user identifier from GH_ACCOUNT
  # Format: "built-in/email@example.com" or empty if not provided
  casdoor_admin_user = var.gh_account != "" ? "built-in/${var.gh_account}" : ""

  # User list for vault-admin role
  vault_admin_users = local.casdoor_admin_user != "" ? [local.casdoor_admin_user] : []
}

# =============================================================================
# Vault Roles
# =============================================================================

resource "restapi_object" "role_vault_admin" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  path          = "/add-role"
  create_path   = "/add-role"
  update_path   = "/update-role?id=admin/{id}"
  update_method = "POST"
  read_path     = "/get-role?id=admin/{id}"
  destroy_path  = "/delete-role?id=admin/{id}"
  id_attribute  = "name"

  data = jsonencode({
    owner       = "admin"
    name        = "vault-admin"
    createdTime = "2025-01-01T00:00:00Z"
    displayName = "Vault Administrator"
    description = "Full administrative access to Vault (read/write/configure)"
    users       = local.vault_admin_users
    groups      = []
    roles       = []
    domains     = []
    isEnabled   = true
  })

  depends_on = [helm_release.casdoor]
}

resource "restapi_object" "role_vault_developer" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  path          = "/add-role"
  create_path   = "/add-role"
  update_path   = "/update-role?id=admin/{id}"
  update_method = "POST"
  read_path     = "/get-role?id=admin/{id}"
  destroy_path  = "/delete-role?id=admin/{id}"
  id_attribute  = "name"

  data = jsonencode({
    owner       = "admin"
    name        = "vault-developer"
    createdTime = "2025-01-01T00:00:00Z"
    displayName = "Vault Developer"
    description = "Read/write access to application secrets (no system config)"
    users       = []
    groups      = []
    roles       = []
    domains     = []
    isEnabled   = true
  })

  depends_on = [helm_release.casdoor]
}

resource "restapi_object" "role_vault_viewer" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  path          = "/add-role"
  create_path   = "/add-role"
  update_path   = "/update-role?id=admin/{id}"
  update_method = "POST"
  read_path     = "/get-role?id=admin/{id}"
  destroy_path  = "/delete-role?id=admin/{id}"
  id_attribute  = "name"

  data = jsonencode({
    owner       = "admin"
    name        = "vault-viewer"
    createdTime = "2025-01-01T00:00:00Z"
    displayName = "Vault Viewer"
    description = "Read-only access to Vault secrets"
    users       = []
    groups      = []
    roles       = []
    domains     = []
    isEnabled   = true
  })

  depends_on = [helm_release.casdoor]
}
