terraform {
  required_version = ">= 1.11.0"

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
