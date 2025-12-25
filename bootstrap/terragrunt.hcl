# =============================================================================
# Bootstrap Layer Configuration
# =============================================================================
# L1 layer - provides K3s cluster and foundational infrastructure
# Must be independent of upper layers (no dependencies on Platform/Data)

include "root" {
  path = find_in_parent_folders()
}

# =============================================================================
# Generate providers.tf
# =============================================================================
# Bootstrap needs cloudflare, aws, and k8s providers
# Override common k8s providers to use fileexists() check (bootstrap creates kubeconfig)

generate "layer_providers" {
  path      = "providers_layer.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    # Bootstrap Layer-Specific Providers
    # Override common k8s providers with fileexists() check (kubeconfig created during bootstrap)

    provider "kubernetes" {
      config_path = fileexists(local.kubeconfig_path) ? local.kubeconfig_path : null
    }

    provider "helm" {
      kubernetes {
        config_path = fileexists(local.kubeconfig_path) ? local.kubeconfig_path : null
      }
    }

    provider "kubectl" {
      config_path      = fileexists(local.kubeconfig_path) ? local.kubeconfig_path : null
      load_config_file = fileexists(local.kubeconfig_path)
    }

    provider "cloudflare" {
      api_token = var.cloudflare_api_token
    }

    provider "aws" {
      # Use default profile or environment variables
      # AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY for R2 backend
    }
  EOF
}

# =============================================================================
# Generate required_providers in versions.tf
# =============================================================================

generate "layer_required_providers" {
  path      = "versions.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
      required_version = ">= 1.11.0"

      required_providers {
        # Common providers (from root terragrunt.hcl)
        kubernetes = {
          source  = "hashicorp/kubernetes"
          version = "~> 2.0"
        }
        helm = {
          source  = "hashicorp/helm"
          version = "~> 2.0"
        }
        kubectl = {
          source  = "alekc/kubectl"
          version = "~> 2.0"
        }

        # Bootstrap layer-specific providers
        aws = {
          source  = "hashicorp/aws"
          version = "~> 5.0"
        }
        cloudflare = {
          source  = "cloudflare/cloudflare"
          version = "~> 4.0"
        }
        dns = {
          source  = "hashicorp/dns"
          version = "~> 3.4"
        }
        http = {
          source  = "hashicorp/http"
          version = "~> 3.5"
        }
        time = {
          source  = "hashicorp/time"
          version = "~> 0.13"
        }
        local = {
          source  = "hashicorp/local"
          version = "~> 2.4"
        }
        null = {
          source  = "hashicorp/null"
          version = "~> 3.2"
        }
      }
    }
  EOF
}
