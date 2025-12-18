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
# E2E Check: OAuth2-Proxy /ping endpoint (Robust with Retries)
# ------------------------------------------------------------
resource "null_resource" "portal_auth_ping" {
  count = local.portal_sso_gate_enabled ? 1 : 0

  triggers = {
    # Re-run when helm release changes
    release_version = helm_release.portal_auth[0].version
  }

  provisioner "local-exec" {
    command = <<EOT
      echo "Waiting for portal auth (OAuth2-Proxy) to be ready at https://auth.${local.internal_domain}/ping ..."
      for i in {1..15}; do
        if curl -s -k --fail https://auth.${local.internal_domain}/ping; then
          echo "✅ Portal auth is ready!"
          exit 0
        fi
        echo "⏳ Attempt $i: Portal auth not ready yet, retrying in 5s..."
        sleep 5
      done
      echo "❌ Error: Portal auth failed to become ready after 75s"
      exit 1
    EOT
  }

  depends_on = [helm_release.portal_auth]
}

# ------------------------------------------------------------
# E2E Summary Output
# ------------------------------------------------------------
output "sso_e2e_status" {
  value = local.portal_sso_gate_enabled ? {
    oidc_discovery = try(data.http.casdoor_oidc_discovery[0].status_code, "skipped")
    portal_auth    = "checked_via_null_resource"
    } : {
    oidc_discovery = "disabled"
    portal_auth    = "disabled"
  }
  description = "E2E SSO validation results"
}
