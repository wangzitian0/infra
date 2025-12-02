terraform {
  required_version = ">= 1.6.0"
  
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    # Uncomment based on your VPS provider
    # digitalocean = {
    #   source  = "digitalocean/digitalocean"
    #   version = "~> 2.0"
    # }
    # upcloud = {
    #   source  = "UpCloudLtd/upcloud"
    #   version = "~> 5.0"
    # }
    # hetzner = {
    #   source  = "hetznercloud/hcloud"
    #   version = "~> 1.45"
    # }
  }
  
  # Remote backend configuration
  # Uncomment and configure based on your choice:
  
  # Option 1: AWS S3
  # backend "s3" {
  #   bucket         = "truealpha-terraform-state"
  #   key            = "infra/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-state-lock"
  # }
  
  # Option 2: Cloudflare R2
  # backend "s3" {
  #   bucket                      = "truealpha-terraform-state"
  #   key                         = "infra/terraform.tfstate"
  #   region                      = "auto"
  #   skip_credentials_validation = true
  #   skip_region_validation      = true
  #   skip_requesting_account_id  = true
  #   endpoints = {
  #     s3 = "https://<account-id>.r2.cloudflarestorage.com"
  #   }
  # }
  
  # Option 3: Local (for initial testing only)
  backend "local" {
    path = "terraform.tfstate"
  }
}

# Cloudflare Provider
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Uncomment based on your VPS provider
# provider "digitalocean" {
#   token = var.do_token
# }

# provider "upcloud" {
#   username = var.upcloud_username
#   password = var.upcloud_password
# }

# provider "hcloud" {
#   token = var.hcloud_token
# }
