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
