terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
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
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

provider "aws" {
  # Use default profile or environment variables
  # AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY for R2 backend
}

# Helm provider - only configure if kubeconfig exists (after k3s deployment)
provider "helm" {
  kubernetes {
    config_path = fileexists(local.kubeconfig_path) ? local.kubeconfig_path : null
  }
}

# Kubernetes provider - only configure if kubeconfig exists (after k3s deployment)
provider "kubernetes" {
  config_path = fileexists(local.kubeconfig_path) ? local.kubeconfig_path : null
}

provider "kubectl" {
  config_path      = fileexists(local.kubeconfig_path) ? local.kubeconfig_path : null
  load_config_file = fileexists(local.kubeconfig_path)
}
