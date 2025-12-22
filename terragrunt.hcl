# =============================================================================
# Root Terragrunt Configuration
# =============================================================================
# This file centralizes backend and provider configuration for all layers,
# eliminating 77% code duplication across L2/L3/L4.
#
# Directory Structure:
#   2.platform/           → L2 singleton (shared by all environments)
#   envs/staging/3.data/  → L3 staging data layer
#   envs/prod/3.data/     → L3 production data layer
#   4.apps/               → L4 singleton control plane (manages all environments)
# =============================================================================

locals {
  # Parse directory structure to determine layer and environment
  # Examples:
  #   /path/to/2.platform              → layer=platform, env=null (singleton)
  #   /path/to/envs/staging/3.data     → layer=data, env=staging
  #   /path/to/envs/prod/4.apps        → layer=apps, env=prod

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
  # Singleton layers (L2): k3s/platform.tfstate
  # Multi-env layers (L3/L4): k3s/data-{env}.tfstate (backward compatible)
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
  EOF
}

# =============================================================================
# Common Required Providers
# =============================================================================
# Define version constraints for common providers

generate "common_required_providers" {
  path      = "versions_providers_common.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.11.0"

      required_providers {
        kubernetes = {
          source  = "hashicorp/kubernetes"
          version = "~> 2.0"
        }
        helm = {
          source  = "hashicorp/helm"
          version = "~> 2.0"
        }
        vault = {
          source  = "hashicorp/vault"
          version = "~> 4.0"
        }
        random = {
          source  = "hashicorp/random"
          version = "~> 3.6"
        }
      }
    }
  EOF
}

# =============================================================================
# Global Inputs (Available to All Layers)
# =============================================================================
# These inputs are automatically passed to all Terraform modules.
# Layer-specific inputs should be defined in layer terragrunt.hcl files.

inputs = {
  # Kubernetes configuration
  kubeconfig_path = get_env("KUBECONFIG_PATH", "")

  # Vault configuration
  vault_address    = get_env("VAULT_ADDR", "http://vault.platform.svc.cluster.local:8200")
  vault_root_token = get_env("VAULT_TOKEN", "")

  # Cloudflare configuration
  cloudflare_api_token = get_env("CLOUDFLARE_API_TOKEN", "")

  # R2 backend variables (for remote state data sources in L3)
  r2_bucket     = get_env("R2_BUCKET", "")
  r2_account_id = get_env("R2_ACCOUNT_ID", "")

  # Environment context (null for singleton layers like L2)
  environment = local.env
}
