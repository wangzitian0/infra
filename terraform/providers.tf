terraform {
  required_version = ">= 1.6.0"

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

provider "aws" {
  # Use default profile or environment variables
  # AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY for R2 backend
}

# Helm provider depends on kubeconfig from k3s provisioning
provider "helm" {
  kubernetes {
    config_path = local.kubeconfig_path
  }
}

# Kubernetes provider for namespace creation
provider "kubernetes" {
  config_path = local.kubeconfig_path
}
