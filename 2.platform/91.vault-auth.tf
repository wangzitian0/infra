# Vault OIDC Authentication Configuration
# Connects Vault to Casdoor for SSO login
# Retry: 2025-12-17 trigger apply

resource "vault_jwt_auth_backend" "oidc" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  description        = "OIDC backend for Casdoor"
  path               = "oidc"
  type               = "oidc"
  oidc_discovery_url = "https://${local.casdoor_domain}"
  oidc_client_id     = "vault-oidc"
  oidc_client_secret = local.vault_oidc_client_secret

  # Auto-select role based on user's Casdoor roles
  # Priority: vault-admin > vault-developer > vault-viewer
  # If no role matches, falls back to viewer
  default_role = "vault-viewer"

  tune {
    default_lease_ttl = "1h"
    max_lease_ttl     = "8h"
    token_type        = "default-service"
  }

  # Shift-left: Ensure Casdoor apps are configured first
  depends_on = [data.http.casdoor_oidc_discovery]

  lifecycle {
    precondition {
      condition     = local.vault_oidc_client_secret != ""
      error_message = "vault_oidc_client_secret is empty. Casdoor apps may not have been configured."
    }
  }
}

# =============================================================================
# Vault OIDC Roles (Casdoor Role-Based Mapping)
# =============================================================================

# Admin Role: Full access for vault-admin Casdoor role
resource "vault_jwt_auth_backend_role" "vault_admin" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  backend    = vault_jwt_auth_backend.oidc[0].path
  role_name  = "vault-admin"
  user_claim = "sub"
  role_type  = "oidc"

  # Required: must match the client_id used in Casdoor
  bound_audiences = ["vault-oidc"]

  # Only allow users with vault-admin role in Casdoor
  # Casdoor returns roles as array in JWT token's "roles" claim
  bound_claims = {
    roles = "vault-admin"
  }

  # OIDC scopes to request
  oidc_scopes = ["openid", "profile", "email"]

  allowed_redirect_uris = [
    "https://secrets.${local.internal_domain}/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback"
  ]

  token_policies = ["admin"]
  token_ttl      = 3600

  # Enable verbose logging for debugging OIDC issues
  verbose_oidc_logging = true
}

# Developer Role: Read/write access for vault-developer Casdoor role
resource "vault_jwt_auth_backend_role" "vault_developer" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  backend    = vault_jwt_auth_backend.oidc[0].path
  role_name  = "vault-developer"
  user_claim = "sub"
  role_type  = "oidc"

  bound_audiences = ["vault-oidc"]

  # Only allow users with vault-developer role in Casdoor
  bound_claims = {
    roles = "vault-developer"
  }

  oidc_scopes = ["openid", "profile", "email"]

  allowed_redirect_uris = [
    "https://secrets.${local.internal_domain}/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback"
  ]

  token_policies = ["developer"]
  token_ttl      = 3600

  verbose_oidc_logging = true
}

# Viewer Role: Read-only access for vault-viewer Casdoor role
resource "vault_jwt_auth_backend_role" "vault_viewer" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  backend    = vault_jwt_auth_backend.oidc[0].path
  role_name  = "vault-viewer"
  user_claim = "sub"
  role_type  = "oidc"

  bound_audiences = ["vault-oidc"]

  # Only allow users with vault-viewer role in Casdoor
  bound_claims = {
    roles = "vault-viewer"
  }

  oidc_scopes = ["openid", "profile", "email"]

  allowed_redirect_uris = [
    "https://secrets.${local.internal_domain}/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback"
  ]

  token_policies = ["viewer"]
  token_ttl      = 3600

  verbose_oidc_logging = true
}

# Legacy 'reader' role for backward compatibility
# Maps to vault-viewer
resource "vault_jwt_auth_backend_role" "reader" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  backend    = vault_jwt_auth_backend.oidc[0].path
  role_name  = "reader"
  user_claim = "sub"
  role_type  = "oidc"

  bound_audiences = ["vault-oidc"]

  # No bound_claims - accessible to anyone
  # Fallback role for users without specific Casdoor roles

  oidc_scopes = ["openid", "profile", "email"]

  allowed_redirect_uris = [
    "https://secrets.${local.internal_domain}/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback"
  ]

  token_policies = ["reader"]
  token_ttl      = 3600

  verbose_oidc_logging = true
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
