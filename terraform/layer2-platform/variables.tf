variable "r2_bucket" {
  description = "Cloudflare R2 bucket name"
  type        = string
}

variable "r2_account_id" {
  description = "Cloudflare R2 Account ID"
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

variable "vps_host" {
  description = "Public IP/DNS of VPS"
  type        = string
}

variable "base_domain" {
  description = "Base domain (e.g. truealpha.club)"
  type        = string
}

variable "env_prefix" {
  description = "Environment prefix"
  type        = string
  default     = "x-staging"
}

variable "infisical_chart_version" {
  type    = string
  default = "1.7.2"
}

variable "infisical_image_tag" {
  type    = string
  default = "v0.154.0"
}

variable "infisical_postgres_password" {
  type      = string
  sensitive = true
}

variable "infisical_postgres_storage" {
  type    = string
  default = "10Gi"
}

variable "infisical_github_client_id" {
  type    = string
  default = ""
}

variable "infisical_github_client_secret" {
  type      = string
  sensitive = true
  default   = ""
}

# Cloudflare provider required by L2?
# Checked main.tf, it didn't pass token.
# But 2.platform might use it implicitly if provider block is in variables? No.
# If 2.platform has `required_providers { cloudflare }`, it inherits from root.
# So we need to configure cloudflare provider here.

variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID" # Might be needed by module
  type        = string
}
