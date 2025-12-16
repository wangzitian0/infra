# ============================================================
# Locals for 4.apps layer
# ============================================================
locals {
  # Use internal_domain directly (has default in variables.tf)
  # DO NOT fallback to base_domain - this caused wrong Ingress hosts
  internal_domain = var.internal_domain

  # SSO Gate control
  portal_sso_gate_enabled = var.enable_portal_sso_gate
}
