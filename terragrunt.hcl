# Terragrunt Root Configuration
# Reduces 77% configuration duplication across L1-L4 layers
# See: https://github.com/wangzitian0/infra/issues/328

# Detect current layer name from directory
locals {
  # Extract layer name: "1.bootstrap" -> "bootstrap", "2.platform" -> "platform"
  layer_dir  = basename(get_terragrunt_dir())
  layer_name = replace(local.layer_dir, "/^[0-9]+\\./", "")

  # Generate state key based on layer
  # "1.bootstrap" -> "k3s/bootstrap.tfstate"
  # "2.platform" -> "k3s/platform.tfstate"
  # "3.data" -> "k3s/data-${workspace}.tfstate" (handled in layer config)
  state_key = "k3s/${local.layer_name}.tfstate"
}

# Unified Backend Configuration (replaces 4x backend.tf files)
# Cloudflare R2 (S3-compatible) backend
remote_state {
  backend = "s3"

  config = {
    bucket   = get_env("R2_BUCKET")
    key      = local.state_key
    region   = "auto"

    endpoints = {
      s3 = "https://${get_env("R2_ACCOUNT_ID")}.r2.cloudflarestorage.com"
    }

    # R2-specific skip flags
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

# Global inputs (available to all layers)
# These variables will be automatically passed to all Terraform modules
inputs = {
  # Kubernetes access (empty string = use in-cluster credentials)
  kubeconfig_path = get_env("KUBECONFIG_PATH", "")

  # Vault access (root token for initial setup)
  vault_address    = get_env("VAULT_ADDR", "")
  vault_root_token = get_env("VAULT_TOKEN", "")

  # Cloudflare API token (for DNS management)
  cloudflare_api_token = get_env("CLOUDFLARE_API_TOKEN", "")
}
