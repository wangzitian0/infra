# ============================================================
# E2E Validation: Final SSO Health Checks
# ============================================================
# These checks run AFTER all components are deployed.
# They verify the complete SSO flow is working end-to-end.
#
# Individual component checks are in their respective files:
# - 90.casdoor-apps.tf: OIDC discovery endpoint
# - 91.vault-auth.tf: Client secret precondition
# - 92.portal-auth.tf: Casdoor availability precondition

# ------------------------------------------------------------
# E2E Check: OAuth2-Proxy /ping endpoint
# ------------------------------------------------------------
data "http" "portal_auth_ping" {
  count = local.portal_sso_gate_enabled ? 1 : 0

  url = "https://auth.${local.internal_domain}/ping"

  depends_on = [helm_release.portal_auth]

  lifecycle {
    postcondition {
      condition     = self.status_code == 200 || self.status_code == 202
      error_message = "Portal auth (OAuth2-Proxy) /ping failed. Status: ${self.status_code}"
    }
  }
}

# ------------------------------------------------------------
# E2E Summary Output
# ------------------------------------------------------------
output "sso_e2e_status" {
  value = local.portal_sso_gate_enabled ? {
    oidc_discovery = try(data.http.casdoor_oidc_discovery[0].status_code, "skipped")
    portal_auth    = try(data.http.portal_auth_ping[0].status_code, "skipped")
  } : "SSO gate disabled"
  description = "E2E SSO validation results"
}
