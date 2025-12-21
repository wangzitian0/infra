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

  path          = "/add-provider"
  create_path   = "/add-provider"
  update_path   = "/update-provider?id=admin/{id}"
  update_method = "POST"
  # Whitebox: Explicitly use {id} to force ID into the query parameter.
  # Expected: /api/get-provider?id=admin/GitHub
  read_path    = "/get-provider?id=admin/{id}"
  destroy_path = "/delete-provider?id=admin/{id}"
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

  lifecycle {
    precondition {
      condition     = var.github_oauth_client_id != "" && var.github_oauth_client_secret != ""
      error_message = "GitHub OAuth credentials are missing. Check ATLANTIS_GH_CLIENT_ID/SECRET."
    }
  }
}

# =============================================================================
# 2. OIDC Applications
# =============================================================================

# Helper local for common app settings
locals {
  common_app_config = {
    owner          = "admin"
    organization   = "built-in"
    enablePassword = true
    signinMethods = [
      {
        name        = "Password"
        displayName = "Password"
        rule        = "All"
      }
    ]
    signupItems          = []
    grantTypes           = ["authorization_code", "refresh_token"]
    tokenFormat          = "JWT"
    expireInHours        = 168
    refreshExpireInHours = 168
    # Updated API fields for Casdoor v1.570+
    providers = [
      {
        owner     = "admin"
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

  path          = "/add-application"
  create_path   = "/add-application"
  update_path   = "/update-application?id=admin/{id}"
  update_method = "POST"
  read_path     = "/get-application?id=admin/{id}"
  destroy_path  = "/delete-application?id=admin/{id}"
  id_attribute  = "name"

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
  count = local.casdoor_oidc_enabled ? 1 : 0

  path          = "/add-application"
  create_path   = "/add-application"
  update_path   = "/update-application?id=admin/{id}"
  update_method = "POST"
  read_path     = "/get-application?id=admin/{id}"
  destroy_path  = "/delete-application?id=admin/{id}"
  id_attribute  = "name"

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
  count = local.casdoor_oidc_enabled ? 1 : 0

  path          = "/add-application"
  create_path   = "/add-application"
  update_path   = "/update-application?id=admin/{id}"
  update_method = "POST"
  read_path     = "/get-application?id=admin/{id}"
  destroy_path  = "/delete-application?id=admin/{id}"
  id_attribute  = "name"

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
  count = local.casdoor_oidc_enabled ? 1 : 0

  path          = "/add-application"
  create_path   = "/add-application"
  update_path   = "/update-application?id=admin/{id}"
  update_method = "POST"
  read_path     = "/get-application?id=admin/{id}"
  destroy_path  = "/delete-application?id=admin/{id}"
  id_attribute  = "name"

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
  count = local.casdoor_oidc_enabled ? 1 : 0

  url = "https://${local.casdoor_domain}/.well-known/openid-configuration"

  request_headers = {
    Accept = "application/json"
  }

  depends_on = [
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

# =============================================================================
# 3. SAML Applications (PostHog)
# =============================================================================

# PostHog SAML Application
# NOTE: SAML configuration is experimental. If it fails, PostHog can still
# be deployed with local auth. SAML can be configured manually in PostHog UI.
resource "restapi_object" "app_posthog_saml" {
  count = local.casdoor_oidc_enabled ? 1 : 0

  path          = "/add-application"
  create_path   = "/add-application"
  update_path   = "/update-application?id=admin/{id}"
  update_method = "POST"
  read_path     = "/get-application?id=admin/{id}"
  destroy_path  = "/delete-application?id=admin/{id}"
  id_attribute  = "name"

  data = jsonencode({
    owner        = "admin"
    organization = "built-in"
    name         = "posthog-saml"
    displayName  = "PostHog SAML"

    # SAML-specific configuration (fields to be validated via Casdoor API)
    # If these fields are incorrect, Terraform plan/apply will fail
    # gracefully without affecting other applications.
    enableSamlCompress = true
    samlReplyUrl       = "https://posthog.${local.internal_domain}/complete/saml/"

    # SAML attribute mapping (PostHog expects these attributes)
    samlAttributes = [
      { name = "email", value = "email" },
      { name = "firstName", value = "firstName" },
      { name = "lastName", value = "lastName" }
    ]

    # Common fields
    enablePassword = true
    signupItems    = []

    # GitHub provider for unified login experience
    providers = [
      {
        owner     = "admin"
        name      = "GitHub"
        canSignUp = true
        canSignIn = true
        canUnlink = true
        rule      = "None"
      }
    ]
  })

  depends_on = [restapi_object.provider_github]

  # NOTE: If this resource fails, it will not block other Casdoor apps
  # (Vault/Kubero) due to independent resource graphs. PostHog deployment
  # in L4 will check for SAML app existence and gracefully degrade to
  # local auth if SAML is unavailable.
}
