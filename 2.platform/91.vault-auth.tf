# Vault OIDC Authentication Configuration
# Connects Vault to Casdoor for SSO login
# Retry: 2025-12-17 trigger apply

resource "vault_jwt_auth_backend" "oidc" {
  count = local.portal_sso_gate_enabled ? 1 : 0

  description        = "OIDC backend for Casdoor"
  path               = "oidc"
  type               = "oidc"
  oidc_discovery_url = "https://${local.casdoor_domain}"
  oidc_client_id     = "vault-oidc"
  oidc_client_secret = local.vault_oidc_client_secret
  default_role       = "reader"

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

resource "vault_jwt_auth_backend_role" "reader" {
  count = local.portal_sso_gate_enabled ? 1 : 0

  backend    = vault_jwt_auth_backend.oidc[0].path
  role_name  = "reader"
  user_claim = "sub"
  role_type  = "oidc"
  
  # Required: must match the client_id used in Casdoor
  bound_audiences = ["vault-oidc"]
  
  # OIDC scopes to request
  oidc_scopes = ["openid", "profile", "email"]
  
  allowed_redirect_uris = [
    "https://secrets.${local.internal_domain}/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback"
  ]
  token_policies = ["reader"]
  token_ttl      = 3600
}

# Default reader policy
resource "vault_policy" "reader" {
  count = local.portal_sso_gate_enabled ? 1 : 0

  name   = "reader"
  policy = <<-EOT
    # Read-only permission on secrets
    path "secret/*" {
      capabilities = ["read", "list"]
    }
    # List enabled secrets engines
    path "sys/mounts" {
      capabilities = ["read", "list"]
    }
  EOT
}