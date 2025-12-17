# ============================================================
# Shift-Left: SSO & Platform Checks
# ============================================================
# These checks validate SSO configuration before apply completes.
# If any check fails, terraform apply will fail with a clear error.

# ------------------------------------------------------------
# Check 1: OIDC Discovery endpoint reachable
# ------------------------------------------------------------
data "http" "casdoor_oidc_discovery" {
  count = local.portal_sso_gate_enabled ? 1 : 0

  url = "https://${local.casdoor_domain}/.well-known/openid-configuration"

  request_headers = {
    Accept = "application/json"
  }

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Casdoor OIDC discovery endpoint not reachable at https://${local.casdoor_domain}/.well-known/openid-configuration. Status: ${self.status_code}"
    }
  }
}

# ------------------------------------------------------------
# Check 2: Casdoor API accessible (health check)
# ------------------------------------------------------------
data "http" "casdoor_health" {
  count = local.portal_sso_gate_enabled ? 1 : 0

  url = "https://${local.casdoor_domain}/api/health"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200 || self.status_code == 404
      error_message = "Casdoor API not accessible at https://${local.casdoor_domain}/api/health. Status: ${self.status_code}"
    }
  }
}

# ------------------------------------------------------------
# Check 3: OAuth2-Proxy (Portal Auth) reachable
# ------------------------------------------------------------
data "http" "portal_auth_ping" {
  count = local.portal_sso_gate_enabled ? 1 : 0

  url = "https://auth.${local.internal_domain}/ping"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200 || self.status_code == 202
      error_message = "Portal auth (OAuth2-Proxy) not reachable at https://auth.${local.internal_domain}/ping. Status: ${self.status_code}. Is portal-auth helm release deployed?"
    }
  }

  depends_on = [helm_release.portal_auth]
}

# ------------------------------------------------------------
# Check 4: Vault OIDC config prerequisites
# ------------------------------------------------------------
resource "terraform_data" "vault_oidc_prereq_check" {
  count = local.portal_sso_gate_enabled ? 1 : 0

  lifecycle {
    precondition {
      condition     = local.vault_oidc_client_secret != ""
      error_message = "vault_oidc_client_secret is empty. Casdoor apps may not have been created yet."
    }
  }

  depends_on = [data.http.casdoor_oidc_discovery]
}

# ------------------------------------------------------------
# Outputs for debugging
# ------------------------------------------------------------
output "sso_checks_passed" {
  value = local.portal_sso_gate_enabled ? {
    oidc_discovery = try(data.http.casdoor_oidc_discovery[0].status_code, "skipped")
    casdoor_health = try(data.http.casdoor_health[0].status_code, "skipped")
    portal_auth    = try(data.http.portal_auth_ping[0].status_code, "skipped")
  } : "SSO gate disabled"
  description = "SSO validation check results"
}
