# Casdoor OIDC Applications Management via RestAPI Provider
# Replaces legacy local-exec script

# =============================================================================
# Portal Gate App
# =============================================================================
resource "restapi_object" "portal_gate_app" {
  count = local.portal_gate_enabled ? 1 : 0
  
  path          = "/api/add-application"
  read_path     = "/api/get-application?id=admin/portal-gate"
  update_path   = "/api/update-application"
  update_method = "POST"
  destroy_path  = "/api/delete-application"
  destroy_method = "POST"
  object_id     = "portal-gate"

  data = jsonencode({
    owner = "admin"
    name  = "portal-gate"
    displayName = "Portal Gate"
    organization = "built-in"
    clientId = "portal-gate"
    clientSecret = local.casdoor_portal_gate_client_secret
    redirectUris = ["https://auth.${local.internal_domain}/oauth2/callback"]
    enablePassword = false
    providers = [{
      owner = ""
      name = "GitHub"
      canSignUp = true
      canSignIn = true
      canUnlink = true
      rule = "None"
    }]
    grantTypes = ["authorization_code", "refresh_token"]
  })
  
  debug = true
}

# =============================================================================
# Vault OIDC App
# =============================================================================
resource "restapi_object" "vault_oidc_app" {
  count = local.portal_gate_enabled ? 1 : 0
  
  path          = "/api/add-application"
  read_path     = "/api/get-application?id=admin/vault-oidc"
  update_path   = "/api/update-application"
  update_method = "POST"
  destroy_path  = "/api/delete-application"
  destroy_method = "POST"
  object_id     = "vault-oidc"

  data = jsonencode({
    owner = "admin"
    name  = "vault-oidc"
    displayName = "Vault OIDC"
    organization = "built-in"
    clientId = "vault-oidc"
    clientSecret = local.vault_oidc_client_secret
    redirectUris = ["https://secrets.${local.internal_domain}/ui/vault/auth/oidc/oidc/callback"]
    enablePassword = false
    providers = [{
      owner = ""
      name = "GitHub"
      canSignUp = true
      canSignIn = true
      canUnlink = true
      rule = "None"
    }]
    grantTypes = ["authorization_code", "refresh_token"]
  })

  debug = true
}

# =============================================================================
# Dashboard OIDC App
# =============================================================================
resource "restapi_object" "dashboard_oidc_app" {
  count = local.portal_gate_enabled ? 1 : 0
  
  path          = "/api/add-application"
  read_path     = "/api/get-application?id=admin/dashboard-oidc"
  update_path   = "/api/update-application"
  update_method = "POST"
  destroy_path  = "/api/delete-application"
  destroy_method = "POST"
  object_id     = "dashboard-oidc"

  data = jsonencode({
    owner = "admin"
    name  = "dashboard-oidc"
    displayName = "Dashboard OIDC"
    organization = "built-in"
    clientId = "dashboard-oidc"
    clientSecret = local.dashboard_oidc_client_secret
    redirectUris = ["https://kdashboard.${local.internal_domain}/oauth2/callback"]
    enablePassword = false
    providers = [{
      owner = ""
      name = "GitHub"
      canSignUp = true
      canSignIn = true
      canUnlink = true
      rule = "None"
    }]
    grantTypes = ["authorization_code", "refresh_token"]
  })

  debug = true
}

# =============================================================================
# Kubero OIDC App
# =============================================================================
resource "restapi_object" "kubero_oidc_app" {
  count = local.portal_gate_enabled ? 1 : 0
  
  path          = "/api/add-application"
  read_path     = "/api/get-application?id=admin/kubero-oidc"
  update_path   = "/api/update-application"
  update_method = "POST"
  destroy_path  = "/api/delete-application"
  destroy_method = "POST"
  object_id     = "kubero-oidc"

  data = jsonencode({
    owner = "admin"
    name  = "kubero-oidc"
    displayName = "Kubero OIDC"
    organization = "built-in"
    clientId = "kubero-oidc"
    clientSecret = local.kubero_oidc_client_secret
    redirectUris = ["https://kcloud.${local.internal_domain}/auth/callback"]
    enablePassword = false
    providers = [{
      owner = ""
      name = "GitHub"
      canSignUp = true
      canSignIn = true
      canUnlink = true
      rule = "None"
    }]
    grantTypes = ["authorization_code", "refresh_token"]
  })

  debug = true
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
    restapi_object.portal_gate_app,
    restapi_object.vault_oidc_app
  ]

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Casdoor OIDC discovery not reachable after app config. Status: ${self.status_code}"
    }
  }
}
