# Dokploy automation module (bootstrap Infisical compose)

variable "enable_infisical" {
  description = "Enable Dokploy Infisical bootstrap"
  type        = bool
  default     = false
}

variable "api_url" {
  description = "Dokploy API base URL (e.g. https://cloud.truealpha.club/api)"
  type        = string
  default     = "https://cloud.truealpha.club/api"
}

variable "api_key" {
  description = "Dokploy API key (x-api-key)"
  type        = string
  sensitive   = true
}

variable "organization_id" {
  description = "Optional Dokploy organization id override"
  type        = string
  default     = ""
}

variable "project_name" {
  description = "Dokploy project name"
  type        = string
  default     = "truealpha"
}

variable "environment_name" {
  description = "Dokploy environment name for platform services"
  type        = string
  default     = "platform"
}

variable "compose_name" {
  description = "Compose name inside Dokploy"
  type        = string
  default     = "infisical"
}

variable "compose_app_name" {
  description = "Compose appName (used for container prefix uniqueness)"
  type        = string
  default     = ""
}

variable "compose_file" {
  description = "Path to compose template (will be envsubst'd before upload)"
  type        = string
  default     = ""
}

variable "server_name" {
  description = "Dokploy server name"
  type        = string
  default     = "truealpha-platform"
}

variable "server_ip" {
  description = "Server IP for Dokploy agent/Traefik"
  type        = string
}

variable "server_username" {
  description = "SSH username"
  type        = string
  default     = "root"
}

variable "server_port" {
  description = "SSH port"
  type        = number
  default     = 22
}

variable "server_type" {
  description = "Dokploy server type (deploy/build)"
  type        = string
  default     = "deploy"
}

variable "ssh_key_name" {
  description = "Name for Dokploy SSH key record"
  type        = string
  default     = "infra-ssh"
}

variable "ssh_public_key" {
  description = "Public SSH key contents"
  type        = string
  sensitive   = true
}

variable "ssh_private_key" {
  description = "Private SSH key contents"
  type        = string
  sensitive   = true
}

variable "infisical_host" {
  description = "Hostname for Infisical (e.g. secrets.truealpha.club)"
  type        = string
  default     = "secrets.truealpha.club"
}

variable "infisical_encryption_key" {
  description = "Infisical ENCRYPTION_KEY (32+ chars)"
  type        = string
  sensitive   = true
}

variable "infisical_admin_email" {
  description = "Infisical bootstrap admin email"
  type        = string
}

variable "infisical_admin_password" {
  description = "Infisical bootstrap admin password"
  type        = string
  sensitive   = true
}

variable "infisical_license_key" {
  description = "Optional Infisical license key"
  type        = string
  default     = ""
  sensitive   = true
}

variable "infisical_postgres_user" {
  description = "Infisical Postgres user"
  type        = string
}

variable "infisical_postgres_password" {
  description = "Infisical Postgres password"
  type        = string
  sensitive   = true
}

variable "infisical_postgres_db" {
  description = "Infisical Postgres database name"
  type        = string
  default     = "infisical"
}

variable "infisical_redis_password" {
  description = "Redis password for Infisical"
  type        = string
  default     = "infisical"
  sensitive   = true
}

variable "infisical_traefik_network" {
  description = "Traefik network name (Dokploy default is traefik)"
  type        = string
  default     = "traefik"
}

variable "force_redeploy_token" {
  description = "Optional token to force redeploy when secrets change"
  type        = string
  default     = ""
}
