# Centralized Variables for Bootstrap to Applications
# All variables are defined here because:
# 1. Bootstrap is the only layer with direct secret access (GitHub Secrets)
# 2. Platform+ layers read config from Bootstrap state or Vault
# 3. Single source of truth for variable definitions
# 4. Simplifies tfvars management in CI/CD
#
# Categories:
# - Bootstrap Variables
# Trigger CI: oauth deployment verify, DNS
# - Platform: Vault, Dashboard, Kubero
# - Data/Apps Runtime: Accessed via Vault, not declared here
# ============================================================

variable "vps_host" {
  description = "Public IP or DNS name of the VPS where k3s will be installed"
  type        = string

  validation {
    condition     = length(var.vps_host) > 0
    error_message = "vps_host is required (IP address or DNS name)."
  }
}

# Bootstrap: R2 State Backend
variable "r2_bucket" {
  description = "Cloudflare R2 bucket name for Terraform state"
  type        = string
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID for R2 (S3-compatible)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.aws_access_key_id) >= 16
    error_message = "aws_access_key_id must be at least 16 characters."
  }
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key for R2 (S3-compatible)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.aws_secret_access_key) >= 32
    error_message = "aws_secret_access_key must be at least 32 characters."
  }
}

variable "vps_user" {
  description = "SSH user on the VPS"
  type        = string
  default     = "root"

  validation {
    condition     = length(var.vps_user) > 0
    error_message = "vps_user must be non-empty."
  }
}

variable "ssh_port" {
  description = "SSH port on the VPS"
  type        = number
  default     = 22

  validation {
    condition     = var.ssh_port > 0 && var.ssh_port <= 65535
    error_message = "ssh_port must be in range 1-65535."
  }
}

variable "ssh_private_key" {
  description = "Private key used for SSH (contents of the key, not a path)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.ssh_private_key) > 100 && can(regex("PRIVATE KEY", var.ssh_private_key))
    error_message = "ssh_private_key must be a valid PEM private key."
  }
}

variable "cluster_name" {
  description = "Logical name for this k3s cluster"
  type        = string
  default     = "truealpha-k3s"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,61}[a-z0-9]$", var.cluster_name))
    error_message = "cluster_name must be a valid Kubernetes-style name (dns-1035/dns-1123 label)."
  }
}

variable "api_endpoint" {
  description = "Public address used to reach the k3s API server; defaults to vps_host"
  type        = string
  default     = null
}

variable "k3s_channel" {
  description = "Release channel passed to the k3s installer (stable, latest, etc.)"
  type        = string
  default     = "stable"
}

variable "k3s_version" {
  description = "Optional explicit k3s version (e.g., v1.28.7+k3s1). Leave empty to follow the channel."
  type        = string
  default     = ""
}

variable "disable_components" {
  description = "Components to disable in k3s (passed as --disable flags)"
  type        = list(string)
  default     = []
}

# Shared Infrastructure Toggle
variable "enable_infra" {
  description = "Enable shared infrastructure modules (Bootstrap/Platform). Set to false for app-only deployments (staging/prod)."
  type        = bool
  default     = true
}

# Environment & domain
variable "environment" {
  description = "Environment name (staging, prod, etc.)"
  type        = string
  default     = "staging"
}

variable "base_domain" {
  description = "Production/public base domain (e.g., truealpha.club)"
  type        = string
  default     = "truealpha.club"

  validation {
    condition     = trimspace(var.base_domain) != "" && can(regex("\\.[a-z]{2,}$", var.base_domain))
    error_message = "base_domain must be a valid domain (e.g., example.com)."
  }
}

variable "internal_domain" {
  description = "Domain used for infra hosts (e.g., truealpha.club -> digger.truealpha.club). Defaults to base_domain if empty."
  type        = string
  default     = ""
}

variable "env_prefix" {
  description = "Environment prefix for x-* env hosts (e.g., x-staging, x-test, empty for prod)"
  type        = string
  default     = "x-staging"
}

# Vault PostgreSQL (dedicated)
variable "vault_postgres_password" {
  description = "PostgreSQL password for Vault storage backend (REQUIRED - no default for security)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.vault_postgres_password) >= 16
    error_message = "vault_postgres_password must be at least 16 characters for security."
  }
}

variable "vault_postgres_storage" {
  description = "PostgreSQL storage size for Vault"
  type        = string
  default     = "10Gi"
}

# Redis (Data layer - not yet implemented)
variable "redis_password" {
  description = "Redis password (REQUIRED when enabling Redis)"
  type        = string
  sensitive   = true
  default     = "" # No default - must be provided when Redis is enabled
}

variable "redis_storage" {
  description = "Redis storage size"
  type        = string
  default     = "20Gi"
}

# Neo4j (Data layer - not yet implemented)
variable "neo4j_password" {
  description = "Neo4j password (REQUIRED when enabling Neo4j)"
  type        = string
  sensitive   = true
  default     = "" # No default - must be provided when Neo4j is enabled
}

variable "neo4j_storage" {
  description = "Neo4j storage size"
  type        = string
  default     = "100Gi"
}

# Vault
variable "vault_chart_version" {
  description = "Helm chart version for Vault"
  type        = string
  default     = "0.31.0"
}

variable "vault_image_tag" {
  description = "Vault image tag"
  type        = string
  default     = "1.20.4"
}

# Feature flags
variable "enable_observability" {
  description = "Enable SigNoz and PostHog (staging/prod only)"
  type        = bool
  default     = false
}

variable "enable_ssl" {
  description = "Enable SSL/TLS"
  type        = bool
  default     = true
}

# Digger Orchestrator (CI/CD)
variable "github_token" {
  description = "GitHub Personal Access Token (fallback if App not configured)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_org" {
  description = "GitHub organization name"
  type        = string
  default     = "wangzitian0"

  validation {
    condition     = length(var.github_org) > 0
    error_message = "github_org must be non-empty."
  }
}

variable "github_user" {
  description = "GitHub username"
  type        = string
  default     = "wangzitian0"

  validation {
    condition     = length(var.github_user) > 0
    error_message = "github_user must be non-empty."
  }
}

variable "digger_webhook_secret" {
  description = "Webhook secret for GitHub -> Digger"
  type        = string
  sensitive   = true
  default     = ""
}

# GitHub App Configuration (Infra-Flash)
variable "infra_flash_app_id" {
  description = "GitHub App ID for Infra-Flash (used by Digger)"
  type        = string
  default     = ""

  validation {
    condition     = var.infra_flash_app_id == "" || can(regex("^[0-9]+$", var.infra_flash_app_id))
    error_message = "infra_flash_app_id must be a numeric string."
  }
}

variable "infra_flash_app_key" {
  description = "GitHub App Private Key (PEM) for Infra-Flash (used by Digger)"
  type        = string
  sensitive   = true
  default     = ""
}

# Digger Authentication
variable "digger_bearer_token" {
  description = "Bearer token for Digger API authentication (used by GitHub Actions)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "digger_http_password" {
  description = "Password for Digger Web UI Basic Auth"
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.digger_http_password == "" || length(var.digger_http_password) >= 12
    error_message = "digger_http_password must be at least 12 characters for security."
  }
}

variable "r2_account_id" {
  description = "Cloudflare R2 account ID"
  type        = string
  default     = ""

  validation {
    condition     = var.r2_account_id == "" || length(var.r2_account_id) == 32
    error_message = "r2_account_id must be a 32-character hex string if provided."
  }
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS and Certs"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.cloudflare_api_token) > 0
    error_message = "cloudflare_api_token is required for DNS management."
  }
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the domain"
  type        = string

  validation {
    condition     = length(var.cloudflare_zone_id) == 32
    error_message = "cloudflare_zone_id must be a 32-character hex string."
  }
}

variable "internal_zone_id" {
  description = "Cloudflare Zone ID for the internal/infra domain. If empty, falls back to cloudflare_zone_id."
  type        = string
  default     = ""
}

# OAuth2-Proxy (GitHub OAuth for Dashboard protection)
variable "github_oauth_client_id" {
  description = "GitHub OAuth App Client ID for OAuth2-Proxy"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_oauth_client_secret" {
  description = "GitHub OAuth App Client Secret for OAuth2-Proxy"
  type        = string
  sensitive   = true
  default     = ""
}

# Casdoor SSO
variable "casdoor_admin_password" {
  description = "Casdoor admin password (from 1Password via GitHub Secret CASDOOR_ADMIN_PASSWORD)"
  type        = string
  sensitive   = true
  default     = ""
}

# Bootstrap Admin IP Allowlist
variable "bootstrap_admin_ips" {
  description = "Additional IP CIDRs allowed to access Infrastructure UIs (e.g., office IPs, VPN). GitHub webhook IPs are always included where applicable."
  type        = list(string)
  default     = []
}

# Data layer Vault Access
variable "vault_root_token" {
  description = "Vault root token for L3 secret storage (from 1Password via GitHub Secret VAULT_ROOT_TOKEN)"
  type        = string
  sensitive   = true
  default     = ""
}
