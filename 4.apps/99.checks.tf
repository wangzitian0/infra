# ============================================================
# Shift-Left: Production Safety Checks
# ============================================================
resource "terraform_data" "production_safety_check" {
  lifecycle {
    precondition {
      condition     = var.environment != "prod" || var.kubero_ui_image_tag != "latest"
      error_message = "Production deployment MUST NOT use 'latest' image tag for Kubero UI. Please pin a specific version."
    }
  }
}

# ============================================================
# Shift-Left: Domain Configuration Check
# ============================================================
resource "terraform_data" "domain_config_check" {
  lifecycle {
    precondition {
      condition     = var.internal_domain != "" && var.internal_domain != var.base_domain
      error_message = "internal_domain must be explicitly set and different from base_domain. Expected: zitian.party (infra), Got: ${var.internal_domain}"
    }
  }
}
