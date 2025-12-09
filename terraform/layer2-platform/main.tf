terraform {
  backend "s3" {
    # Partial config, endpoints injected by Atlantis/CI
    workspace_key_prefix = "env:"
  }
}

# Provider Versions (Same as L1)
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
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }
}

variable "r2_bucket" {
  description = "R2 Bucket Name for Remote State Lookup"
  type        = string
}

variable "r2_account_id" {
  description = "R2 Account ID for Remote State Lookup"
  type        = string
}

# Access L1 State (Monolithic 'terraform.tfstate' in 'k3s/')
data "terraform_remote_state" "l1" {
  backend = "s3"
  config = {
    bucket = var.r2_bucket
    key    = "k3s/terraform.tfstate"
    endpoints = {
      s3 = "https://${var.r2_account_id}.r2.cloudflarestorage.com"
    }
    # Using same credentials as current execution
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}

# Configure Providers using L1 Output
provider "kubernetes" {
  host = data.terraform_remote_state.l1.outputs.api_endpoint

  # Kubeconfig content from L1 state
  # Note: L1 output is "content" (string). Kubernetes provider can take config_path or raw config.
  # But providers block handles `config_path`. For raw content we use client_certificate etc.
  # Since fetched kubeconfig is a single file, we can write it to disk?
  # Or use `config_path` if we write it.
  # Or parse it.

  # Simplest: Write to file in CI/Atlantis setup?
  # The goal is to AVOID ssh.
  # If we have the content in state, we can use `local_file` resource to materialize it?
  # But provider init happens before graph?
  # Using `helm` provider with `config_path` requires file existence.

  # Alternative: YAML Decode
}

locals {
  kubeconfig = yamldecode(data.terraform_remote_state.l1.outputs.kubeconfig)

  host                   = local.kubeconfig.clusters[0].cluster.server
  client_certificate     = base64decode(local.kubeconfig.users[0].user["client-certificate-data"])
  client_key             = base64decode(local.kubeconfig.users[0].user["client-key-data"])
  cluster_ca_certificate = base64decode(local.kubeconfig.clusters[0].cluster["certificate-authority-data"])
}

provider "kubernetes" {
  host                   = local.host
  client_certificate     = local.client_certificate
  client_key             = local.client_key
  cluster_ca_certificate = local.cluster_ca_certificate
}

provider "helm" {
  kubernetes {
    host                   = local.host
    client_certificate     = local.client_certificate
    client_key             = local.client_key
    cluster_ca_certificate = local.cluster_ca_certificate
  }
}

provider "kubectl" {
  host                   = local.host
  client_certificate     = local.client_certificate
  client_key             = local.client_key
  cluster_ca_certificate = local.cluster_ca_certificate
  load_config_file       = false
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

locals {
  namespaces = {
    nodep         = "nodep"
    security      = "security"
    apps          = "apps"
    data          = "data"
    ingestion     = "ingestion"
    orchestration = "orchestration"
    observability = "observability"
    platform      = "platform" # Kubero etc
  }
}

# Use the existing Platform Module
module "platform" {
  source = "../2.platform"

  infisical_chart_version     = var.infisical_chart_version
  infisical_image_tag         = var.infisical_image_tag
  infisical_postgres_password = var.infisical_postgres_password
  infisical_postgres_storage  = var.infisical_postgres_storage

  env_prefix  = var.env_prefix
  base_domain = var.base_domain
  namespaces  = local.namespaces

  # kubeconfig_path is required by variable definition but not used.
  # We pass empty string or dummy path.
  kubeconfig_path = "/dev/null"

  vps_host = var.vps_host

  # Infisical GitHub OAuth
  infisical_github_client_id     = var.infisical_github_client_id
  infisical_github_client_secret = var.infisical_github_client_secret
}
