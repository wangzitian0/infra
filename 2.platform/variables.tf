# L2 Platform Variables
# Variables are populated from Atlantis environment (TF_VAR_*) set in 1.bootstrap/2.atlantis.tf
# Some have defaults for standalone testing.

variable "kubeconfig_path" {
  description = "Path to kubeconfig file (set via TF_VAR_kubeconfig_path in Atlantis)"
  type        = string
  default     = "" # Set by Atlantis via TF_VAR_kubeconfig_path
}

variable "env_prefix" {
  description = "Environment prefix for domain names (e.g., 'staging', 'x-staging', or empty for prod)"
  type        = string
  default     = "" # Empty means production
}

variable "base_domain" {
  description = "Base domain for all services"
  type        = string
  default     = "truealpha.club"
}

variable "infisical_chart_version" {
  description = "Infisical Helm chart version"
  type        = string
  default     = "1.7.2"
}

variable "infisical_image_tag" {
  description = "Infisical Docker image tag"
  type        = string
  default     = "v0.92.0-postgres"
}

variable "infisical_postgres_password" {
  description = "PostgreSQL password for Infisical (sensitive, set via TF_VAR_*)"
  type        = string
  sensitive   = true
  default     = "" # Must be provided via TF_VAR_infisical_postgres_password
}

variable "infisical_postgres_storage" {
  description = "Storage size for Infisical PostgreSQL PVC"
  type        = string
  default     = "8Gi"
}

variable "namespaces" {
  description = "Map of namespace names"
  type        = map(string)
  default = {
    nodep         = "nodep"
    security      = "security"
    apps          = "apps"
    data          = "data"
    ingestion     = "ingestion"
    kubero        = "kubero"
    observability = "observability"
  }
}

variable "vps_host" {
  description = "VPS host IP for DNS records (set via TF_VAR_vps_host in Atlantis)"
  type        = string
  default     = "" # Set by Atlantis
}

variable "infisical_github_client_id" {
  description = "GitHub OAuth App Client ID for Infisical SSO"
  type        = string
  default     = ""
}

variable "infisical_github_client_secret" {
  description = "GitHub OAuth App Client Secret for Infisical SSO"
  type        = string
  default     = ""
  sensitive   = true
}

