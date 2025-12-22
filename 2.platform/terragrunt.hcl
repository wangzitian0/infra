# =============================================================================
# L2 Platform Layer Configuration
# =============================================================================
# Singleton layer providing platform services (Vault, Casdoor, Dashboard, etc.)
# Shared by all environments (staging and prod both depend on this single instance)

include "root" {
  path = find_in_parent_folders()
}

# =============================================================================
# Generate providers.tf
# =============================================================================
# Providers specific to L2 platform layer

generate "providers" {
  path      = "providers.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
    # L2 Platform Provider Configuration
    # When running in Atlantis (in-cluster), kubeconfig_path can be empty.
    # Providers will auto-detect in-cluster ServiceAccount credentials.

    provider "kubernetes" {
      config_path = var.kubeconfig_path != "" ? var.kubeconfig_path : null
    }

    provider "helm" {
      kubernetes {
        config_path = var.kubeconfig_path != "" ? var.kubeconfig_path : null
      }
    }

    provider "kubectl" {
      config_path      = var.kubeconfig_path != "" ? var.kubeconfig_path : null
      load_config_file = var.kubeconfig_path != ""
    }

    provider "cloudflare" {
      api_token = var.cloudflare_api_token
    }

    provider "vault" {
      address         = var.vault_address
      token           = var.vault_root_token
      skip_tls_verify = true
    }

    provider "clickhousedbops" {
      host     = var.clickhouse_host != "" ? var.clickhouse_host : "clickhouse.data-staging.svc.cluster.local"
      port     = 8123
      protocol = "http"

      auth_config = {
        strategy = "basicauth"
        username = "default"
        password = random_password.l3_clickhouse.result
      }
    }

    # Cloudflare zone data source for internal domain (used by Casdoor DNS)
    data "cloudflare_zone" "internal" {
      name = local.internal_domain
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
        cloudflare = {
          source  = "cloudflare/cloudflare"
          version = "~> 4.0"
        }
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
        random = {
          source  = "hashicorp/random"
          version = "~> 3.6"
        }
        null = {
          source  = "hashicorp/null"
          version = "~> 3.2"
        }
        vault = {
          source  = "hashicorp/vault"
          version = "~> 4.0"
        }
        restapi = {
          source  = "Mastercard/restapi"
          version = "1.20.0"
        }
        time = {
          source  = "hashicorp/time"
          version = "~> 0.11"
        }
        clickhousedbops = {
          source  = "ClickHouse/clickhousedbops"
          version = "1.1.0"
        }
      }
    }
  EOF
}
