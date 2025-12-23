# =============================================================================
# Root Terragrunt Configuration
# =============================================================================
# This file centralizes backend and provider configuration for all modules,
# eliminating code duplication across Platform and Data layers.
#
# Directory Structure:
#   platform/           → Platform singleton (shared by all environments)
#   envs/staging/data/  → Staging data layer
#   envs/prod/data/     → Production data layer
# =============================================================================

locals {
  # Parse directory structure to determine layer and environment
  # Examples:
  #   /path/to/platform              → layer=platform, env=null (singleton)
  #   /path/to/envs/staging/data     → layer=data, env=staging

  path_components = split("/", get_terragrunt_dir())

  # Check if we're in envs/ subdirectory
  in_envs_dir = contains(local.path_components, "envs")

  # Extract environment (staging/prod) if in envs/, otherwise null
  env = local.in_envs_dir ? element([
    for i, component in local.path_components :
      local.path_components[i + 1]
      if component == "envs"
  ], 0) : null

  # Extract layer name from directory (e.g., "2.platform" → "platform", "3.data" → "data")
  current_dir = basename(get_terragrunt_dir())
  layer_name  = replace(local.current_dir, "/^[0-9]+\\./", "")

  # Generate state key based on environment and layer
  # Singleton layers: k3s/platform.tfstate
  # Multi-env layers: k3s/data-{env}.tfstate
  state_key = local.env == null ? "k3s/${local.layer_name}.tfstate" : "k3s/${local.layer_name}-${local.env}.tfstate"
}

# =============================================================================
# Unified Backend Configuration (S3-compatible Cloudflare R2)
# =============================================================================
# Replaces duplicate backend.tf files across all layers.
# Backend credentials and bucket info are passed via environment variables:
#   - R2_BUCKET: Cloudflare R2 bucket name
#   - R2_ACCOUNT_ID: Cloudflare account ID
#   - AWS_ACCESS_KEY_ID: R2 access key (for S3 compatibility)
#   - AWS_SECRET_ACCESS_KEY: R2 secret key

remote_state {
  backend = "s3"

  config = {
    bucket   = get_env("R2_BUCKET")
    key      = local.state_key
    region   = "auto"

    endpoints = {
      s3 = "https://${get_env("R2_ACCOUNT_ID")}.r2.cloudflarestorage.com"
    }

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

# =============================================================================
# Common Providers (Shared by All Layers)
# =============================================================================
# Generate common provider configuration to eliminate duplication across layers.
# Layer-specific providers should be defined in layer terragrunt.hcl files.

generate "common_providers" {
  path      = "providers_common.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    # Common Provider Configuration
    # These providers are used by multiple layers and configured once here.

    provider "kubernetes" {
      config_path = var.kubeconfig_path != "" ? var.kubeconfig_path : null
    }

    provider "helm" {
      kubernetes {
        config_path = var.kubeconfig_path != "" ? var.kubeconfig_path : null
      }
    }

    provider "vault" {
      address         = var.vault_address
      token           = var.vault_root_token
      skip_tls_verify = true
    }

    # kubectl provider - used for raw manifests
    provider "kubectl" {
      config_path      = var.kubeconfig_path != "" ? var.kubeconfig_path : null
      load_config_file = var.kubeconfig_path != ""
    }
  EOF
}

# Note: We don't generate common_required_providers here because Terraform
# only allows one required_providers block per module. Each layer generates
# their own complete versions.tf with both common and layer-specific providers.

# =============================================================================
# Global Inputs (Available to All Layers)
# =============================================================================
# These inputs are automatically passed to all Terraform modules via TF_VAR_*.
# Layer-specific inputs should be defined in layer terragrunt.hcl files.
# SSOT: Variables are defined once here and consumed by all layers.

inputs = {
  # === Kubernetes Configuration ===
  kubeconfig_path = get_env("KUBECONFIG_PATH", "")

  # === Vault Configuration ===
  vault_address    = get_env("VAULT_ADDR", "http://vault.platform.svc.cluster.local:8200")
  vault_root_token = get_env("VAULT_TOKEN", "")

  # === Domain Configuration ===
  base_domain     = get_env("BASE_DOMAIN", "truealpha.club")
  internal_domain = get_env("INTERNAL_DOMAIN", "zitian.party")

  # === Cloudflare Configuration ===
  cloudflare_api_token = get_env("CLOUDFLARE_API_TOKEN", "")

  # === R2 Backend (for L3 remote state access) ===
  r2_bucket     = get_env("R2_BUCKET", "")
  r2_account_id = get_env("R2_ACCOUNT_ID", "")

  # Environment Context ===
  # Auto-detected from directory path (null for singleton layers like Platform)
  environment = local.env
}
