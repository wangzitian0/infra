# Casdoor OIDC Applications Management via RestAPI Provider
# Replaces legacy local-exec script

# =============================================================================
# Portal Gate App
# =============================================================================
resource "restapi_object" "portal_gate_app" {
  count = local.portal_gate_enabled ? 1 : 0

  path           = "/api/add-application"
  read_path      = "/api/get-application?id=admin/portal-gate"
  update_path    = "/api/update-application"
  update_method  = "POST"
  destroy_path   = "/api/delete-application"
  destroy_method = "POST"
  object_id      = "portal-gate"

  data = jsonencode({
    owner          = "admin"
    name           = "portal-gate"
    displayName    = "Portal Gate"
    organization   = "built-in"
    clientId       = "portal-gate"
    clientSecret   = local.casdoor_portal_gate_client_secret
    redirectUris   = ["https://auth.${local.internal_domain}/oauth2/callback"]
    enablePassword = false
    providers = [{
      owner     = ""
      name      = "GitHub"
      canSignUp = true
      canSignIn = true
      canUnlink = true
      rule      = "None"
    }]
    grantTypes = ["authorization_code", "refresh_token"]
  })

<<<<<<< HEAD
  debug = true
=======
        # Construct Provider JSON
        local DATA='{
          "owner": "admin",
          "name": "'"$NAME"'",
          "createdTime": "2025-01-01T00:00:00Z",
          "displayName": "'"$NAME"'",
          "category": "OAuth",
          "type": "'"$TYPE"'",
          "clientId": "'"$CLIENT_ID"'",
          "clientSecret": "'"$CLIENT_SECRET"'",
          "organization": "built-in"
        }'

        # Check if provider exists
        RESPONSE=$(curl -sf "$CASDOOR_URL/api/get-provider?id=admin/$NAME" \
          -H "Authorization: Basic $AUTH_HEADER" 2>/dev/null || echo "{}")
        
        if echo "$RESPONSE" | grep -q "\"name\":\"$NAME\""; then
          echo "Updating existing provider: $NAME"
          curl -sf -X POST "$CASDOOR_URL/api/update-provider" \
            -H "Authorization: Basic $AUTH_HEADER" \
            -H "Content-Type: application/json" \
            -d "$DATA" > /dev/null 2>&1 || true
        else
          echo "Creating new provider: $NAME"
          curl -sf -X POST "$CASDOOR_URL/api/add-provider" \
            -H "Authorization: Basic $AUTH_HEADER" \
            -H "Content-Type: application/json" \
            -d "$DATA" > /dev/null 2>&1 || true
        fi
        
        echo "✅ Provider $NAME processed"
      }

      # Configure GitHub Provider
      upsert_provider "GitHub" "$GITHUB_CLIENT_ID" "$GITHUB_CLIENT_SECRET" "GitHub"
      
      # Helper function to upsert application
      # NOTE: Uses grep instead of jq (jq not available in Atlantis pod)
      upsert_app() {
        local APP_NAME="$1"
        local APP_DATA="$2"
        
        echo "=== Processing: $APP_NAME ==="
        
        # Check if app exists by looking for "name" in response
        # Using grep instead of jq since jq is not available in Atlantis
        RESPONSE=$(curl -sf "$CASDOOR_URL/api/get-application?id=admin/$APP_NAME" \
          -H "Authorization: Basic $AUTH_HEADER" 2>/dev/null || echo "{}")
        
        if echo "$RESPONSE" | grep -q "\"name\":\"$APP_NAME\""; then
          echo "Updating existing app: $APP_NAME"
          curl -sf -X POST "$CASDOOR_URL/api/update-application" \
            -H "Authorization: Basic $AUTH_HEADER" \
            -H "Content-Type: application/json" \
            -d "$APP_DATA" > /dev/null 2>&1 || true
        else
          echo "Creating new app: $APP_NAME"
          curl -sf -X POST "$CASDOOR_URL/api/add-application" \
            -H "Authorization: Basic $AUTH_HEADER" \
            -H "Content-Type: application/json" \
            -d "$APP_DATA" > /dev/null 2>&1 || true
        fi
        
        echo "✅ $APP_NAME processed"
      }
      
      # Portal Gate Application
      # Portal SSO Gate - OAuth2-Proxy backed by Casdoor OIDC
      # Provides a forward-auth middleware for Vault/Dashboard/Kubero Ingresses.
      # Retry: 2025-12-17 trigger apply
      upsert_app "portal-gate" '{
        "owner": "admin",
        "name": "portal-gate",
        "displayName": "Portal SSO Gate",
        "organization": "built-in",
        "clientId": "'"$PORTAL_GATE_CLIENT_ID"'",
        "clientSecret": "'"$PORTAL_GATE_CLIENT_SECRET"'",
        "redirectUris": ["https://auth.'"$INTERNAL_DOMAIN"'/oauth2/callback"],
        "enablePassword": false,
        "providers": [{"owner": "", "name": "GitHub", "canSignUp": true, "canSignIn": true, "canUnlink": true, "rule": "None"}],
        "grantTypes": ["authorization_code", "refresh_token"]
      }'
      
      # Vault OIDC Application
      upsert_app "vault-oidc" '{
        "owner": "admin",
        "name": "vault-oidc",
        "displayName": "Vault OIDC",
        "organization": "built-in",
        "clientId": "vault-oidc",
        "clientSecret": "'"$VAULT_OIDC_SECRET"'",
        "redirectUris": ["https://secrets.'"$INTERNAL_DOMAIN"'/ui/vault/auth/oidc/oidc/callback"],
        "enablePassword": false,
        "providers": [{"owner": "", "name": "GitHub", "canSignUp": true, "canSignIn": true, "canUnlink": true, "rule": "None"}],
        "grantTypes": ["authorization_code", "refresh_token"]
      }'
      
      # Dashboard OIDC Application
      upsert_app "dashboard-oidc" '{
        "owner": "admin",
        "name": "dashboard-oidc",
        "displayName": "Dashboard OIDC",
        "organization": "built-in",
        "clientId": "dashboard-oidc",
        "clientSecret": "'"$DASHBOARD_OIDC_SECRET"'",
        "redirectUris": ["https://kdashboard.'"$INTERNAL_DOMAIN"'/oauth2/callback"],
        "enablePassword": false,
        "providers": [{"owner": "", "name": "GitHub", "canSignUp": true, "canSignIn": true, "canUnlink": true, "rule": "None"}],
        "grantTypes": ["authorization_code", "refresh_token"]
      }'
      
      # Kubero OIDC Application
      upsert_app "kubero-oidc" '{
        "owner": "admin",
        "name": "kubero-oidc",
        "displayName": "Kubero OIDC",
        "organization": "built-in",
        "clientId": "kubero-oidc",
        "clientSecret": "'"$KUBERO_OIDC_SECRET"'",
        "redirectUris": ["https://kcloud.'"$INTERNAL_DOMAIN"'/auth/callback"],
        "enablePassword": false,
        "providers": [{"owner": "", "name": "GitHub", "canSignUp": true, "canSignIn": true, "canUnlink": true, "rule": "None"}],
        "grantTypes": ["authorization_code", "refresh_token"]
      }'
      
      echo ""
      echo "=== All OIDC applications processed ==="
    EOT
  }

  depends_on = [helm_release.casdoor]
>>>>>>> 096e05a (fix: correct JSON payload for Casdoor OIDC apps (alertType -> rule))
}

# =============================================================================
# Vault OIDC App
# =============================================================================
resource "restapi_object" "vault_oidc_app" {
  count = local.portal_gate_enabled ? 1 : 0

  path           = "/api/add-application"
  read_path      = "/api/get-application?id=admin/vault-oidc"
  update_path    = "/api/update-application"
  update_method  = "POST"
  destroy_path   = "/api/delete-application"
  destroy_method = "POST"
  object_id      = "vault-oidc"

  data = jsonencode({
    owner          = "admin"
    name           = "vault-oidc"
    displayName    = "Vault OIDC"
    organization   = "built-in"
    clientId       = "vault-oidc"
    clientSecret   = local.vault_oidc_client_secret
    redirectUris   = ["https://secrets.${local.internal_domain}/ui/vault/auth/oidc/oidc/callback"]
    enablePassword = false
    providers = [{
      owner     = ""
      name      = "GitHub"
      canSignUp = true
      canSignIn = true
      canUnlink = true
      rule      = "None"
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

  path           = "/api/add-application"
  read_path      = "/api/get-application?id=admin/dashboard-oidc"
  update_path    = "/api/update-application"
  update_method  = "POST"
  destroy_path   = "/api/delete-application"
  destroy_method = "POST"
  object_id      = "dashboard-oidc"

  data = jsonencode({
    owner          = "admin"
    name           = "dashboard-oidc"
    displayName    = "Dashboard OIDC"
    organization   = "built-in"
    clientId       = "dashboard-oidc"
    clientSecret   = local.dashboard_oidc_client_secret
    redirectUris   = ["https://kdashboard.${local.internal_domain}/oauth2/callback"]
    enablePassword = false
    providers = [{
      owner     = ""
      name      = "GitHub"
      canSignUp = true
      canSignIn = true
      canUnlink = true
      rule      = "None"
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

  path           = "/api/add-application"
  read_path      = "/api/get-application?id=admin/kubero-oidc"
  update_path    = "/api/update-application"
  update_method  = "POST"
  destroy_path   = "/api/delete-application"
  destroy_method = "POST"
  object_id      = "kubero-oidc"

  data = jsonencode({
    owner          = "admin"
    name           = "kubero-oidc"
    displayName    = "Kubero OIDC"
    organization   = "built-in"
    clientId       = "kubero-oidc"
    clientSecret   = local.kubero_oidc_client_secret
    redirectUris   = ["https://kcloud.${local.internal_domain}/auth/callback"]
    enablePassword = false
    providers = [{
      owner     = ""
      name      = "GitHub"
      canSignUp = true
      canSignIn = true
      canUnlink = true
      rule      = "None"
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
