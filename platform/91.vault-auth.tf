# Vault OIDC Authentication Configuration
# Connects Vault to Casdoor for SSO login
# Refactored to use Identity Groups for automatic permission mapping

resource "vault_jwt_auth_backend" "oidc" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  description        = "OIDC backend for Casdoor"
  path               = "oidc"
  type               = "oidc"
  oidc_discovery_url = "https://${local.casdoor_domain}"
  oidc_client_id     = "vault-oidc"
  oidc_client_secret = local.vault_oidc_client_secret

  # default_role is used when no role is specified during login.
  # We use a single 'default' role for everyone, and rely on Identity Groups
  # to assign specific permissions based on JWT claims.
  default_role = "default"

  tune {
    default_lease_ttl = "1h"
    max_lease_ttl     = "8h"
    token_type        = "default-service"
  }

  depends_on = [data.http.casdoor_oidc_discovery]

  lifecycle {
    precondition {
      condition     = local.vault_oidc_client_secret != ""
      error_message = "vault_oidc_client_secret is empty. Casdoor apps may not have been configured."
    }
  }
}

# =============================================================================
# Vault OIDC Roles (Single Entry Point)
# =============================================================================

# Default Role: The single entry point for all OIDC users.
# It grants base access (viewer) and maps Identity Groups for higher privileges.
resource "vault_jwt_auth_backend_role" "default" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  backend    = vault_jwt_auth_backend.oidc[0].path
  role_name  = "default"
  user_claim = "sub"
  role_type  = "oidc"

  # Map the 'roles' claim from JWT to Vault Identity Groups
  groups_claim = "roles"

  bound_audiences = ["vault-oidc"]

  # No bound_claims: Allow all valid Casdoor users to login.
  # Authorization is handled by Identity Groups below.

  oidc_scopes = ["openid", "profile", "email"]

  allowed_redirect_uris = [
    "https://secrets.${local.internal_domain}/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback"
  ]

  # Base policy for everyone (least privilege)
  token_policies = ["viewer"]
  token_ttl      = 3600

  verbose_oidc_logging = true
}

# Legacy 'reader' role alias for backward compatibility scripts
resource "vault_jwt_auth_backend_role" "reader" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  backend   = vault_jwt_auth_backend.oidc[0].path
  role_name = "reader"
  # Reuse configuration from default
  user_claim      = "sub"
  role_type       = "oidc"
  groups_claim    = "roles"
  bound_audiences = ["vault-oidc"]
  oidc_scopes     = ["openid", "profile", "email"]
  allowed_redirect_uris = [
    "https://secrets.${local.internal_domain}/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback"
  ]
  token_policies = ["viewer"]
  token_ttl      = 3600
}

# =============================================================================
# Vault Identity Groups (RBAC Core)
# =============================================================================

# Admin Group
resource "vault_identity_group" "admin" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  name     = "admin"
  type     = "external"
  policies = ["admin"]

  metadata = {
    source = "casdoor-oidc"
  }
}

# Developer Group
resource "vault_identity_group" "developer" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  name     = "developer"
  type     = "external"
  policies = ["developer"]
}

# Viewer Group (Explicit)
# Note: 'default' role already grants viewer policy, but this group
# allows for future viewer-specific logic if needed.
resource "vault_identity_group" "viewer" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  name     = "viewer"
  type     = "external"
  policies = ["viewer"]
}

# =============================================================================
# Vault Identity Group Aliases (Mapping Casdoor Roles to Vault Groups)
# =============================================================================
# We create multiple aliases to handle potential variations in Casdoor's 
# role naming format (e.g. "vault-admin" vs "admin/vault-admin")

# --- Admin Aliases ---

resource "vault_identity_group_alias" "admin_simple" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  name           = "vault-admin"
  mount_accessor = vault_jwt_auth_backend.oidc[0].accessor
  canonical_id   = vault_identity_group.admin[0].id
}

resource "vault_identity_group_alias" "admin_namespaced" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  name           = "admin/vault-admin"
  mount_accessor = vault_jwt_auth_backend.oidc[0].accessor
  canonical_id   = vault_identity_group.admin[0].id
}

resource "vault_identity_group_alias" "admin_builtin" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  name           = "built-in/vault-admin"
  mount_accessor = vault_jwt_auth_backend.oidc[0].accessor
  canonical_id   = vault_identity_group.admin[0].id
}

# --- Developer Aliases ---

resource "vault_identity_group_alias" "developer_simple" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  name           = "vault-developer"
  mount_accessor = vault_jwt_auth_backend.oidc[0].accessor
  canonical_id   = vault_identity_group.developer[0].id
}

resource "vault_identity_group_alias" "developer_namespaced" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  name           = "admin/vault-developer"
  mount_accessor = vault_jwt_auth_backend.oidc[0].accessor
  canonical_id   = vault_identity_group.developer[0].id
}

resource "vault_identity_group_alias" "developer_builtin" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  name           = "built-in/vault-developer"
  mount_accessor = vault_jwt_auth_backend.oidc[0].accessor
  canonical_id   = vault_identity_group.developer[0].id
}

# --- Viewer Aliases ---

resource "vault_identity_group_alias" "viewer_simple" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  name           = "vault-viewer"
  mount_accessor = vault_jwt_auth_backend.oidc[0].accessor
  canonical_id   = vault_identity_group.viewer[0].id
}

resource "vault_identity_group_alias" "viewer_namespaced" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  name           = "admin/vault-viewer"
  mount_accessor = vault_jwt_auth_backend.oidc[0].accessor
  canonical_id   = vault_identity_group.viewer[0].id
}

# =============================================================================
# Vault Policies (Role-Based Access Control)
# =============================================================================

# Viewer Policy: Read-only access
resource "vault_policy" "viewer" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  name   = "viewer"
  policy = <<-EOT
    # Read-only permission on secrets
    path "secret/*" {
      capabilities = ["read", "list"]
    }
    # List enabled secrets engines
    path "sys/mounts" {
      capabilities = ["read", "list"]
    }
    # Required for Vault UI
    path "sys/internal/ui/mounts/*" {
      capabilities = ["read"]
    }
    # Allow reading own token info
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }
    # Allow reading OIDC auth config (for OIDC login flow)
    path "auth/oidc/role/*" {
      capabilities = ["read"]
    }
  EOT
}

# Developer Policy: Read/write access to application secrets
resource "vault_policy" "developer" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  name   = "developer"
  policy = <<-EOT
    # Read/write permission on application secrets
    path "secret/data/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    path "secret/metadata/*" {
      capabilities = ["read", "list"]
    }
    # List enabled secrets engines
    path "sys/mounts" {
      capabilities = ["read", "list"]
    }
    # Required for Vault UI
    path "sys/internal/ui/mounts/*" {
      capabilities = ["read"]
    }
    # Allow reading own token info
    path "auth/token/lookup-self" {
      capabilities = ["read"]
    }
    # Allow reading OIDC auth config
    path "auth/oidc/role/*" {
      capabilities = ["read"]
    }
    # Allow renewing own token
    path "auth/token/renew-self" {
      capabilities = ["update"]
    }
  EOT
}

# Admin Policy: Full administrative access
resource "vault_policy" "admin" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  name   = "admin"
  policy = <<-EOT
    # Full access to secrets
    path "secret/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    # Manage secrets engines
    path "sys/mounts/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    # Manage auth methods
    path "sys/auth/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    # Manage policies
    path "sys/policies/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    # Required for Vault UI
    path "sys/internal/ui/mounts/*" {
      capabilities = ["read"]
    }
    # Token management
    path "auth/token/*" {
      capabilities = ["create", "read", "update", "delete", "list", "sudo"]
    }
    # OIDC configuration
    path "auth/oidc/*" {
      capabilities = ["create", "read", "update", "delete", "list"]
    }
    # System health and capabilities
    path "sys/health" {
      capabilities = ["read"]
    }
    path "sys/capabilities-self" {
      capabilities = ["update"]
    }
  EOT
}

# Legacy 'reader' policy for backward compatibility
# Maps to 'viewer' policy
resource "vault_policy" "reader" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  name   = "reader"
  policy = vault_policy.viewer[0].policy
}
