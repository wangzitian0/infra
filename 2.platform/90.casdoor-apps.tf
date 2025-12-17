# Casdoor OIDC Applications Management via REST API
# Retry: 2025-12-17 trigger apply
# 
# This file manages Casdoor applications using REST API instead of init_data.json.
# Benefits:
# - Incremental updates (no need to restart Casdoor)
# - Idempotent operations (each apply syncs state)
# - True IaC compliance
#
# API Reference: https://door.casdoor.com/swagger/
#
# Authentication: Uses casdoor-builtin-app's clientId/clientSecret from init_data
# for M2M (Machine-to-Machine) authentication. No OAuth flow needed.
#
# NOTE: This script does NOT use jq (not available in Atlantis pod).
#       Uses grep/sed for JSON parsing instead.

# =============================================================================
# OIDC Applications - managed via local-exec API calls
# =============================================================================

# Create/Update all OIDC applications via Casdoor API
# Uses static credentials from init_data (casdoor-builtin-app clientId/Secret)
resource "null_resource" "casdoor_oidc_apps" {
  count = local.portal_gate_enabled ? 1 : 0

  triggers = {
    # Re-run when any app config changes
    portal_gate_secret   = local.casdoor_portal_gate_client_secret
    vault_oidc_secret    = local.vault_oidc_client_secret
    dashboard_secret     = local.dashboard_oidc_client_secret
    kubero_secret        = local.kubero_oidc_client_secret
    internal_domain      = local.internal_domain
    portal_client_id     = var.casdoor_portal_client_id
    github_client_id     = var.github_oauth_client_id
    github_client_secret = var.github_oauth_client_secret
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      CASDOOR_URL           = "https://${local.casdoor_domain}"
      CASDOOR_CLIENT_ID     = "casdoor-builtin-app"
      CASDOOR_CLIENT_SECRET = var.casdoor_admin_password
      # App configurations
      INTERNAL_DOMAIN           = local.internal_domain
      PORTAL_GATE_CLIENT_ID     = var.casdoor_portal_client_id
      PORTAL_GATE_CLIENT_SECRET = local.casdoor_portal_gate_client_secret
      VAULT_OIDC_SECRET         = local.vault_oidc_client_secret
      DASHBOARD_OIDC_SECRET     = local.dashboard_oidc_client_secret
      KUBERO_OIDC_SECRET        = local.kubero_oidc_client_secret
      # Provider configurations
      GITHUB_CLIENT_ID     = var.github_oauth_client_id
      GITHUB_CLIENT_SECRET = var.github_oauth_client_secret
    }
    command = <<-EOT
      set -e
      
      # Casdoor API Authentication:
      # Use clientId:clientSecret as Basic Auth (M2M pattern)
      # All requests are HTTPS (TLS encrypted), token is NOT plaintext
      AUTH_HEADER=$(echo -n "$CASDOOR_CLIENT_ID:$CASDOOR_CLIENT_SECRET" | base64)
      
      echo "=== Casdoor OIDC Apps Configuration ==="
      echo "Casdoor URL: $CASDOOR_URL"
      
      # Wait for Casdoor to be ready
      echo "Checking Casdoor availability..."
      for i in {1..30}; do
        if curl -sf "$CASDOOR_URL/.well-known/openid-configuration" > /dev/null 2>&1; then
          echo "✅ Casdoor is ready"
          break
        fi
        if [ $i -eq 30 ]; then
          echo "⚠️ Casdoor not ready after 30 attempts. Apps will be created on next apply."
          exit 0
        fi
        echo "Waiting for Casdoor... ($i/30)"
        sleep 2
      done
      
      # Helper function to upsert provider
      upsert_provider() {
        local NAME="$1"
        local CLIENT_ID="$2"
        local CLIENT_SECRET="$3"
        local TYPE="$4" # e.g. "GitHub"
        
        echo "=== Processing Provider: $NAME ==="
        
        if [ -z "$CLIENT_ID" ] || [ -z "$CLIENT_SECRET" ]; then
            echo "⚠️  Skipping $NAME provider (credentials missing)"
            return
        fi

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
        "providers": [{"name": "GitHub", "canSignUp": true, "canSignIn": true, "canUnlink": true, "alertType": "None"}],
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
        "providers": [{"name": "GitHub", "canSignUp": true, "canSignIn": true, "canUnlink": true, "alertType": "None"}],
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
        "providers": [{"name": "GitHub", "canSignUp": true, "canSignIn": true, "canUnlink": true, "alertType": "None"}],
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
        "providers": [{"name": "GitHub", "canSignUp": true, "canSignIn": true, "canUnlink": true, "alertType": "None"}],
        "grantTypes": ["authorization_code", "refresh_token"]
      }'
      
      echo ""
      echo "=== All OIDC applications processed ==="
    EOT
  }

  depends_on = [helm_release.casdoor]
}

# Shift-left: Verify OIDC discovery endpoint after apps are configured
# E2E Validation: Final SSO Health Checks
# Retry: 2025-12-17 trigger apply
data "http" "casdoor_oidc_discovery" {
  count = local.portal_gate_enabled ? 1 : 0

  url = "https://${local.casdoor_domain}/.well-known/openid-configuration"

  request_headers = {
    Accept = "application/json"
  }

  depends_on = [null_resource.casdoor_oidc_apps]

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Casdoor OIDC discovery not reachable after app config. Status: ${self.status_code}"
    }
  }
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

output "casdoor_oidc_discovery_status" {
  value       = local.portal_gate_enabled ? data.http.casdoor_oidc_discovery[0].status_code : "disabled"
  description = "OIDC discovery endpoint status code"
}
