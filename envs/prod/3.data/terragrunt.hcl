# =============================================================================
# L3 Data Layer Configuration - Production Environment
# =============================================================================
# Provides data services (PostgreSQL, ClickHouse) for production environment

include "root" {
  path = find_in_parent_folders()
}

# =============================================================================
# Layer Dependencies
# =============================================================================
# L3 depends on L2 platform for infrastructure services

dependency "platform" {
  config_path = "../../../2.platform"

  # Mock outputs for plan-time (before L2 is applied)
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
    # L3 Data Layer Provider Configuration
    # When running in Atlantis (in-cluster), kubeconfig_path can be empty.

    provider "kubernetes" {
      config_path = var.kubeconfig_path != "" ? var.kubeconfig_path : null
    }

    provider "kubectl" {
      config_path      = var.kubeconfig_path != "" ? var.kubeconfig_path : null
      load_config_file = var.kubeconfig_path != ""
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

    provider "clickhousedbops" {
      host     = var.clickhouse_host != "" ? var.clickhouse_host : "clickhouse.$${local.namespace_name}.svc.cluster.local"
      port     = 8123
      protocol = "http"

      auth_config = {
        strategy = "basicauth"
        username = "default"
        password = data.vault_kv_secret_v2.clickhouse.data["password"]
      }
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
        kubectl = {
          source  = "alekc/kubectl"
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
          version = "~> 3.0"
        }
        time = {
          source  = "hashicorp/time"
          version = "~> 0.9"
        }
        clickhousedbops = {
          source  = "ClickHouse/clickhousedbops"
          version = "~> 0.1"
        }
      }
    }
  EOF
}
