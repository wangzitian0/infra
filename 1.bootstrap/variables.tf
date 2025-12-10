# ============================================================
# Centralized Variables for L1-L4
# ============================================================
# All variables are defined here because:
# 1. L1 is the only layer with direct secret access (GitHub Secrets)
# 2. L2+ layers read config from L1 state or Vault
# 3. Single source of truth for variable definitions
# 4. Simplifies tfvars management in CI/CD
#
# Categories:
# - L1 Bootstrap: VPS, K3s, DNS, Atlantis
# - L2 Platform: Vault, Dashboard, Kubero
# - L3+ Runtime: Accessed via Vault, not declared here
# ============================================================

variable "vps_host" {
  description = "Public IP or DNS name of the VPS where k3s will be installed"
  type        = string
}

# L1 Bootstrap: R2 State Backend
variable "r2_bucket" {
  description = "Cloudflare R2 bucket name for Terraform state"
  type        = string
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID for R2 (S3-compatible)"
  type        = string
  sensitive   = true
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key for R2 (S3-compatible)"
  type        = string
  sensitive   = true
}

variable "vps_user" {
  description = "SSH user on the VPS"
  type        = string
  default     = "root"
}

variable "ssh_port" {
  description = "SSH port on the VPS"
  type        = number
  default     = 22
}

variable "ssh_private_key" {
  description = "Private key used for SSH (contents of the key, not a path)"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Logical name for this k3s cluster"
  type        = string
  default     = "truealpha-k3s"
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
  description = "Enable shared infrastructure modules (L1/L2). Set to false for app-only deployments (staging/prod)."
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
    condition     = trim(var.base_domain) != ""
    error_message = "base_domain must be non-empty (set TF_VAR_base_domain or BASE_DOMAIN secret)."
  }
}

variable "internal_domain" {
  description = "Domain used for infra hosts (e.g., truealpha.club -> atlantis.truealpha.club). Defaults to base_domain if empty."
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
  # No default - must be provided via tfvars or -var flag
}

variable "vault_postgres_storage" {
  description = "PostgreSQL storage size for Vault"
  type        = string
  default     = "10Gi"
}

# Redis
variable "redis_password" {
  description = "Redis password"
  type        = string
  sensitive   = true
  default     = "CHANGE_ME"
}

variable "redis_storage" {
  description = "Redis storage size"
  type        = string
  default     = "20Gi"
}

# Neo4j
variable "neo4j_password" {
  description = "Neo4j password"
  type        = string
  sensitive   = true
  default     = "CHANGE_ME"
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

# Atlantis (Terraform CI/CD)
variable "github_token" {
  description = "GitHub Personal Access Token for Atlantis"
  type        = string
  sensitive   = true
  default     = ""
}

variable "github_org" {
  description = "GitHub organization name for Atlantis allowlist"
  type        = string
  default     = "wangzitian0"
}

variable "github_user" {
  description = "GitHub username for Atlantis"
  type        = string
  default     = "wangzitian0"
}

variable "atlantis_webhook_secret" {
  description = "Webhook secret for GitHub -> Atlantis"
  type        = string
  sensitive   = true
  default     = ""
}

# GitHub App Configuration (preferred over PAT for Atlantis)
variable "github_app_id" {
  description = "GitHub App ID for Atlantis (optional)"
  type        = string
  default     = ""
}

variable "github_app_key" {
  description = "GitHub App Private Key (PEM) for Atlantis (optional)"
  type        = string
  sensitive   = true
  default     = ""
}

# Atlantis Web UI Authentication
variable "atlantis_web_username" {
  description = "Username for Atlantis Web UI Basic Auth"
  type        = string
  default     = "admin"
}

variable "atlantis_web_password" {
  description = "Password for Atlantis Web UI Basic Auth (REQUIRED - no default for security)"
  type        = string
  sensitive   = true
}

variable "r2_account_id" {
  description = "Cloudflare R2 account ID"
  type        = string
  default     = ""
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token for DNS and Certs"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for the domain"
  type        = string
}

variable "internal_zone_id" {
  description = "Cloudflare Zone ID for the internal/infra domain. If empty, falls back to cloudflare_zone_id."
  type        = string
  default     = ""
}

# OAuth2-Proxy (GitHub OAuth for Dashboard/Atlantis protection)
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
