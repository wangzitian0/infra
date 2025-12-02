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

variable "vps_count" {
  description = "Number of VPS instances"
  type        = number
  default     = 1
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
