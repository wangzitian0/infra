# Casdoor OIDC Applications Management via REST API
# 
# This file manages Casdoor applications using REST API instead of init_data.json.
# Benefits:
# - Incremental updates (no need to restart Casdoor)
# - Idempotent operations (each apply syncs state)
# - True IaC compliance
#
# API Reference: https://door.casdoor.com/swagger/

# =============================================================================
# Helper: Get Access Token for Casdoor API
# Casdoor uses client credentials flow for M2M authentication
# =============================================================================

data "http" "casdoor_token" {
  count = local.casdoor_enabled ? 1 : 0

  url    = "https://${local.casdoor_domain}/api/login/oauth/access_token"
  method = "POST"

  request_headers = {
    Content-Type = "application/x-www-form-urlencoded"
  }

  request_body = "grant_type=client_credentials&client_id=casdoor-builtin-app&client_secret=${urlencode(var.casdoor_admin_password)}"

  depends_on = [helm_release.casdoor]

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Failed to get Casdoor access token: HTTP ${self.status_code}"
    }
  }
}

locals {
  casdoor_access_token = local.casdoor_enabled ? jsondecode(data.http.casdoor_token[0].response_body).access_token : ""
}

# =============================================================================
# OIDC Applications
# =============================================================================

# Portal Gate Application (used by oauth2-proxy)
resource "restapi_object" "portal_gate_app" {
  provider = restapi.casdoor
  count    = local.portal_gate_enabled ? 1 : 0

  path         = "/api/add-application"
  read_path    = "/api/get-application?id=admin/portal-gate"
  update_path  = "/api/update-application"
  destroy_path = "/api/delete-application"

  id_attribute = "data/name"

  data = jsonencode({
    owner          = "admin"
    name           = "portal-gate"
    displayName    = "Portal SSO Gate"
    organization   = "built-in"
    clientId       = var.casdoor_portal_client_id
    clientSecret   = local.casdoor_portal_gate_client_secret
    redirectUris   = ["https://auth.${local.internal_domain}/oauth2/callback"]
    enablePassword = false
    grantTypes     = ["authorization_code", "refresh_token"]
  })

  headers = {
    Authorization = "Bearer ${local.casdoor_access_token}"
    Content-Type  = "application/json"
  }

  depends_on = [helm_release.casdoor, data.http.casdoor_token]
}

# Vault OIDC Application
resource "restapi_object" "vault_oidc_app" {
  provider = restapi.casdoor
  count    = local.portal_gate_enabled ? 1 : 0

  path         = "/api/add-application"
  read_path    = "/api/get-application?id=admin/vault-oidc"
  update_path  = "/api/update-application"
  destroy_path = "/api/delete-application"

  id_attribute = "data/name"

  data = jsonencode({
    owner          = "admin"
    name           = "vault-oidc"
    displayName    = "Vault OIDC"
    organization   = "built-in"
    clientId       = "vault-oidc"
    clientSecret   = local.vault_oidc_client_secret
    redirectUris   = ["https://secrets.${local.internal_domain}/ui/vault/auth/oidc/oidc/callback"]
    enablePassword = false
    grantTypes     = ["authorization_code", "refresh_token"]
  })

  headers = {
    Authorization = "Bearer ${local.casdoor_access_token}"
    Content-Type  = "application/json"
  }

  depends_on = [helm_release.casdoor, data.http.casdoor_token]
}

# Dashboard OIDC Application
resource "restapi_object" "dashboard_oidc_app" {
  provider = restapi.casdoor
  count    = local.portal_gate_enabled ? 1 : 0

  path         = "/api/add-application"
  read_path    = "/api/get-application?id=admin/dashboard-oidc"
  update_path  = "/api/update-application"
  destroy_path = "/api/delete-application"

  id_attribute = "data/name"

  data = jsonencode({
    owner          = "admin"
    name           = "dashboard-oidc"
    displayName    = "Dashboard OIDC"
    organization   = "built-in"
    clientId       = "dashboard-oidc"
    clientSecret   = local.dashboard_oidc_client_secret
    redirectUris   = ["https://kdashboard.${local.internal_domain}/oauth2/callback"]
    enablePassword = false
    grantTypes     = ["authorization_code", "refresh_token"]
  })

  headers = {
    Authorization = "Bearer ${local.casdoor_access_token}"
    Content-Type  = "application/json"
  }

  depends_on = [helm_release.casdoor, data.http.casdoor_token]
}

# Kubero OIDC Application
resource "restapi_object" "kubero_oidc_app" {
  provider = restapi.casdoor
  count    = local.portal_gate_enabled ? 1 : 0

  path         = "/api/add-application"
  read_path    = "/api/get-application?id=admin/kubero-oidc"
  update_path  = "/api/update-application"
  destroy_path = "/api/delete-application"

  id_attribute = "data/name"

  data = jsonencode({
    owner          = "admin"
    name           = "kubero-oidc"
    displayName    = "Kubero OIDC"
    organization   = "built-in"
    clientId       = "kubero-oidc"
    clientSecret   = local.kubero_oidc_client_secret
    redirectUris   = ["https://kcloud.${local.internal_domain}/auth/callback"]
    enablePassword = false
    grantTypes     = ["authorization_code", "refresh_token"]
  })

  headers = {
    Authorization = "Bearer ${local.casdoor_access_token}"
    Content-Type  = "application/json"
  }

  depends_on = [helm_release.casdoor, data.http.casdoor_token]
}

# =============================================================================
# Outputs
# =============================================================================

output "casdoor_apps_managed" {
  value = local.portal_gate_enabled ? [
    "portal-gate",
    "vault-oidc",
    "dashboard-oidc",
    "kubero-oidc"
  ] : []
  description = "Casdoor applications managed via REST API"
}
