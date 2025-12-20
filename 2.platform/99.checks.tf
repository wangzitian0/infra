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

# Whitebox tracking of the ping target
resource "terraform_data" "health_check_target" {
  count = local.portal_sso_gate_enabled ? 1 : 0
  input = "https://auth.${local.internal_domain}/ping"
}

# 2. Verify readiness after the cooldown period
data "http" "portal_auth_ping" {
  count = local.portal_sso_gate_enabled ? 1 : 0

  url = terraform_data.health_check_target[0].output

  depends_on = [time_sleep.wait_for_portal_auth]

  lifecycle {
    postcondition {
      condition     = self.status_code == 200 || self.status_code == 202
      error_message = "Portal auth (OAuth2-Proxy) at ${terraform_data.health_check_target[0].output} failed after 60s. Check Ingress/DNS/Pod."
    }
  }
}

# ------------------------------------------------------------
# E2E Summary Output
# ------------------------------------------------------------
output "sso_e2e_status" {
  value = {
    oidc_discovery = local.casdoor_oidc_enabled ? try(data.http.casdoor_oidc_discovery[0].status_code, "failed") : "disabled"
    portal_auth    = local.portal_sso_gate_enabled ? try(data.http.portal_auth_ping[0].status_code, "failed") : "disabled"
    target_url     = local.portal_sso_gate_enabled ? try(terraform_data.health_check_target[0].output, "n/a") : "n/a"
  }
  description = "E2E SSO validation results with target URL for debugging"
}
