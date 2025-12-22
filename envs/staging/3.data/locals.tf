# =============================================================================
# Read L2 Platform Outputs (Issue #301)
# Native Terraform layer dependency: L3 reads L2 outputs
# =============================================================================
data "terraform_remote_state" "l2_platform" {
  backend = "s3"
  config = {
    bucket                      = var.r2_bucket
    key                         = "k3s/platform.tfstate"
    region                      = "auto"
    endpoints                   = { s3 = "https://${var.r2_account_id}.r2.cloudflarestorage.com" }
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
