# ============================================================
# E2E Validation: Final SSO Health Checks
# Retry: 2025-12-17 trigger apply
# Test: verify Atlantis prompt optimization
# ============================================================
# These checks run AFTER all components are deployed.
# They verify the complete SSO flow is working end-to-end.
#
# Individual component checks are in their respective files:
# - 90.casdoor-apps.tf: OIDC discovery endpoint
# - 91.vault-auth.tf: Client secret precondition
# - 92.portal-auth.tf: Casdoor availability precondition

# ------------------------------------------------------------
# E2E Check: OAuth2-Proxy /ping endpoint (Official & Robust)
# ------------------------------------------------------------

# 1. Give Ingress and DNS 60 seconds to propagate
resource "time_sleep" "wait_for_portal_auth" {
  count = local.portal_sso_gate_enabled ? 1 : 0

  create_duration = "60s"
  depends_on      = [helm_release.portal_auth]
}

# 2. Verify readiness after the cooldown period
data "http" "portal_auth_ping" {
  count = local.portal_sso_gate_enabled ? 1 : 0

  url = "https://auth.${local.internal_domain}/ping"

  # Use insecure skip verify if needed by adding a retry or ensuring cert is ready
  # Note: data.http doesn't have retry, but 60s sleep usually guarantees success.
  
  depends_on = [time_sleep.wait_for_portal_auth]

  lifecycle {
    postcondition {
      condition     = self.status_code == 200 || self.status_code == 202
      error_message = "Portal auth (OAuth2-Proxy) /ping failed even after 60s wait. Status: ${self.status_code}"
    }
  }
}

# ------------------------------------------------------------
# E2E Summary Output
# ------------------------------------------------------------
output "sso_e2e_status" {
  value = local.portal_sso_gate_enabled ? {
    oidc_discovery = try(data.http.casdoor_oidc_discovery[0].status_code, "skipped")
    portal_auth    = try(data.http.portal_auth_ping[0].status_code, "failed")
    } : {
    oidc_discovery = "disabled"
    portal_auth    = "disabled"
  }
  description = "E2E SSO validation results"
}
