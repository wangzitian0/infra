# =============================================================================
# L4 Apps Layer Configuration - Singleton
# =============================================================================
# Control plane layer (Kubero GitOps, SigNoz observability)
# Deployed as singleton - manages workloads across all environments
# Environment separation is handled at application level (Kubero Pipeline/Phase)

include "root" {
  path = find_in_parent_folders()
}

# =============================================================================
# Layer Dependencies
# =============================================================================
# L4 depends on L2 (platform) for infrastructure services

dependency "platform" {
  config_path = "../2.platform"

  mock_outputs = {
    vault_address = "http://vault.platform.svc.cluster.local:8200"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
}

# =============================================================================
# Generate providers.tf
# =============================================================================

generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    # L4 Apps Layer Provider Configuration

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

    provider "kubectl" {
      config_path      = var.kubeconfig_path != "" ? var.kubeconfig_path : null
      load_config_file = var.kubeconfig_path != ""
    }
  EOF
}

# =============================================================================
# Generate required_providers in versions.tf
# =============================================================================

generate "required_providers" {
  path      = "versions_providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    terraform {
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
        kubectl = {
          source  = "alekc/kubectl"
          version = "~> 2.0"
        }
        random = {
          source  = "hashicorp/random"
          version = "~> 3.0"
        }
      }
    }
  EOF
}
