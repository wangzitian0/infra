locals {
  internal_domain         = var.internal_domain != "" ? var.internal_domain : var.base_domain
  portal_sso_gate_enabled = var.enable_portal_sso_gate
}
