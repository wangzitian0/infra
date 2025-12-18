# Casdoor OIDC Applications Management via RestAPI Provider
# Replaces previous local-exec/curl scripts for better state management.
#
# Provider: Mastercard/restapi
# Configured in providers.tf
#
# Resources:
# - GitHub Identity Provider
# - Portal SSO Gate (OAuth2-Proxy)
# - Vault OIDC
# - Dashboard OIDC
# - Kubero OIDC

# =============================================================================
# 1. Identity Providers
# =============================================================================

resource "restapi_object" "provider_github" {
  count = local.casdoor_enabled ? 1 : 0

  path         = "/api/add-provider"
  create_path  = "/api/add-provider"
  update_path  = "/api/update-provider"
  read_path    = "/api/get-provider?id=admin" # Appends /{name} -> ?id=admin/GitHub
  destroy_path = "/api/delete-provider"
  id_attribute = "name"

  data = jsonencode({
    owner        = "admin"
    name         = "GitHub"
    createdTime  = "2025-01-01T00:00:00Z"
    displayName  = "GitHub"
    category     = "OAuth"
    type         = "GitHub"
    clientId     = var.github_oauth_client_id
    clientSecret = var.github_oauth_client_secret
    organization = "built-in"
  })

  # Wait for Casdoor to be healthy
  depends_on = [helm_release.casdoor]
}

# =============================================================================
# 2. OIDC Applications
# =============================================================================

# Helper local for common app settings
locals {
  common_app_config = {
    owner          = "admin"
    organization   = "built-in"
    enablePassword = false
    grantTypes     = ["authorization_code", "refresh_token"]
    # Updated API fields for Casdoor v1.570+
    providers = [
      {
        owner     = ""
        name      = "GitHub"
        canSignUp = true
        canSignIn = true
        canUnlink = true
        rule      = "None" # Replaces alertType
      }
    ]
  }
}

# Portal Gate Application
resource "restapi_object" "app_portal_gate" {
  count = local.portal_gate_enabled ? 1 : 0

  path         = "/api/add-application"
  create_path  = "/api/add-application"
  update_path  = "/api/update-application"
  read_path    = "/api/get-application?id=admin"
  destroy_path = "/api/delete-application"
  id_attribute = "name"

  data = jsonencode(merge(local.common_app_config, {
    name         = "portal-gate"
    displayName  = "Portal SSO Gate"
    clientId     = var.casdoor_portal_client_id
    clientSecret = local.casdoor_portal_gate_client_secret
    redirectUris = ["https://auth.${local.internal_domain}/oauth2/callback"]
  }))

  depends_on = [restapi_object.provider_github]
}

# Vault OIDC Application
resource "restapi_object" "app_vault_oidc" {
  count = local.portal_gate_enabled ? 1 : 0

  path         = "/api/add-application"
  create_path  = "/api/add-application"
  update_path  = "/api/update-application"
  read_path    = "/api/get-application?id=admin"
  destroy_path = "/api/delete-application"
  id_attribute = "name"

  data = jsonencode(merge(local.common_app_config, {
    name         = "vault-oidc"
    displayName  = "Vault OIDC"
    clientId     = "vault-oidc"
    clientSecret = local.vault_oidc_client_secret
    redirectUris = ["https://secrets.${local.internal_domain}/ui/vault/auth/oidc/oidc/callback"]
  }))

  depends_on = [restapi_object.provider_github]
}

# Dashboard OIDC Application
resource "restapi_object" "app_dashboard_oidc" {
  count = local.portal_gate_enabled ? 1 : 0

  path         = "/api/add-application"
  create_path  = "/api/add-application"
  update_path  = "/api/update-application"
  read_path    = "/api/get-application?id=admin"
  destroy_path = "/api/delete-application"
  id_attribute = "name"

  data = jsonencode(merge(local.common_app_config, {
    name         = "dashboard-oidc"
    displayName  = "Dashboard OIDC"
    clientId     = "dashboard-oidc"
    clientSecret = local.dashboard_oidc_client_secret
    redirectUris = ["https://kdashboard.${local.internal_domain}/oauth2/callback"]
  }))

  depends_on = [restapi_object.provider_github]
}

# Kubero OIDC Application
resource "restapi_object" "app_kubero_oidc" {
  count = local.portal_gate_enabled ? 1 : 0

  path         = "/api/add-application"
  create_path  = "/api/add-application"
  update_path  = "/api/update-application"
  read_path    = "/api/get-application?id=admin"
  destroy_path = "/api/delete-application"
  id_attribute = "name"

  data = jsonencode(merge(local.common_app_config, {
    name         = "kubero-oidc"
    displayName  = "Kubero OIDC"
    clientId     = "kubero-oidc"
    clientSecret = local.kubero_oidc_client_secret
    redirectUris = ["https://kcloud.${local.internal_domain}/auth/callback"]
  }))

  depends_on = [restapi_object.provider_github]
}

# =============================================================================
# Checks / Discovery
# =============================================================================
data "http" "casdoor_oidc_discovery" {
  count = local.portal_gate_enabled ? 1 : 0

  url = "https://${local.casdoor_domain}/.well-known/openid-configuration"

  request_headers = {
    Accept = "application/json"
  }

  depends_on = [
    restapi_object.app_portal_gate,
    restapi_object.app_vault_oidc,
    restapi_object.app_dashboard_oidc,
    restapi_object.app_kubero_oidc
  ]

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Casdoor OIDC discovery not reachable after app config. Status: ${self.status_code}"
    }
  }
}
