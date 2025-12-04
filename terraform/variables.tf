# Global Variables

variable "environment" {
  description = "Environment name (dev, test, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "test", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, staging, prod."
  }
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "truealpha"
}

variable "domain" {
  description = "Root domain name"
  type        = string
}

# Cloudflare

variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID"
  type        = string
}

# VPS Configuration (adjust based on provider)

variable "vps_ip" {
  description = "VPS IP address (for existing/manual VPS)"
  type        = string
  default     = ""
}

variable "vps_count" {
  description = "Number of VPS instances"
  type        = number
  default     = 1
}

variable "enable_vps_bootstrap" {
  description = "Enable automated VPS bootstrap (Docker, Dokploy, etc.)"
  type        = bool
  default     = false
}

variable "ssh_user" {
  description = "SSH user for VPS access"
  type        = string
  default     = "prod"
}

variable "ssh_private_key" {
  description = "SSH private key for VPS access (leave empty if using ssh-agent)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "vps_size" {
  description = "VPS instance size/type"
  type        = string
}

variable "vps_region" {
  description = "VPS region"
  type        = string
  default     = "nyc1"
}

variable "ssh_keys" {
  description = "SSH key IDs or fingerprints"
  type        = list(string)
  default     = []
}

# Database Configuration

variable "enable_managed_database" {
  description = "Whether to provision managed database"
  type        = bool
  default     = false
}

variable "database_size" {
  description = "Database instance size"
  type        = string
  default     = "db-s-1vcpu-1gb"
}

# Monitoring

variable "enable_monitoring" {
  description = "Enable monitoring and alerting"
  type        = bool
  default     = true
}

# Tags

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# Dokploy / Infisical bootstrap
variable "enable_dokploy_infisical" {
  description = "Enable Dokploy API bootstrap for self-hosted Infisical"
  type        = bool
  default     = false
}

variable "dokploy_api_url" {
  description = "Dokploy API base URL"
  type        = string
  default     = "https://cloud.truealpha.club/api"
}

variable "dokploy_api_key" {
  description = "Dokploy API key (x-api-key header)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "dokploy_organization_id" {
  description = "Optional Dokploy organization id override"
  type        = string
  default     = ""
}

variable "dokploy_project_name" {
  description = "Dokploy project name"
  type        = string
  default     = "truealpha"
}

variable "dokploy_environment_name" {
  description = "Dokploy environment name for platform services"
  type        = string
  default     = "platform"
}

variable "dokploy_compose_name" {
  description = "Compose name for Infisical"
  type        = string
  default     = "infisical"
}

variable "dokploy_compose_file" {
  description = "Path to Infisical compose template"
  type        = string
  default     = ""
}

variable "dokploy_server_name" {
  description = "Dokploy server name"
  type        = string
  default     = "truealpha-platform"
}

variable "dokploy_server_username" {
  description = "Dokploy server SSH username"
  type        = string
  default     = "root"
}

variable "dokploy_server_port" {
  description = "Dokploy server SSH port"
  type        = number
  default     = 22
}

variable "dokploy_server_type" {
  description = "Dokploy server type"
  type        = string
  default     = "deploy"
}

variable "dokploy_ssh_key_name" {
  description = "Dokploy SSH key record name"
  type        = string
  default     = "infra-ssh"
}

variable "dokploy_ssh_public_key" {
  description = "Public SSH key content for Dokploy"
  type        = string
  sensitive   = true
  default     = ""
}

variable "dokploy_ssh_private_key" {
  description = "Private SSH key content for Dokploy"
  type        = string
  sensitive   = true
  default     = ""
}

variable "infisical_host" {
  description = "Infisical host (secrets.truealpha.club)"
  type        = string
  default     = "secrets.truealpha.club"
}

variable "infisical_encryption_key" {
  description = "Infisical ENCRYPTION_KEY"
  type        = string
  sensitive   = true
  default     = ""
}

variable "infisical_admin_email" {
  description = "Infisical bootstrap admin email"
  type        = string
  default     = ""
}

variable "infisical_admin_password" {
  description = "Infisical bootstrap admin password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "infisical_license_key" {
  description = "Optional Infisical license key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "infisical_postgres_user" {
  description = "Infisical Postgres user"
  type        = string
  default     = ""
}

variable "infisical_postgres_password" {
  description = "Infisical Postgres password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "infisical_postgres_db" {
  description = "Infisical Postgres database name"
  type        = string
  default     = "infisical"
}

variable "infisical_redis_password" {
  description = "Infisical Redis password"
  type        = string
  sensitive   = true
  default     = "infisical"
}

variable "infisical_traefik_network" {
  description = "Traefik network name for Infisical"
  type        = string
  default     = "traefik"
}

variable "dokploy_force_redeploy_token" {
  description = "Change this value to force redeploy when secrets rotate"
  type        = string
  default     = ""
}
