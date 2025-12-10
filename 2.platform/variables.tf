# L2 Platform Variables (Vault)
# Populated via TF_VAR_* from 1.bootstrap/2.atlantis.tf

variable "kubeconfig_path" {
  description = "Path to kubeconfig file (set via TF_VAR_kubeconfig_path in Atlantis)"
  type        = string
  default     = ""
}

variable "env_prefix" {
  description = "Environment prefix for domain names (e.g., 'staging', 'x-staging', or empty for prod)"
  type        = string
  default     = ""
}

variable "base_domain" {
  description = "Base domain for all services"
  type        = string
  default     = "truealpha.club"
}

variable "internal_domain" {
  description = "Internal/infra domain (falls back to base_domain if empty)"
  type        = string
  default     = ""
}

variable "vault_chart_version" {
  description = "Vault Helm chart version"
  type        = string
  default     = "0.31.0"
}

variable "vault_image_tag" {
  description = "Vault image tag"
  type        = string
  default     = "1.20.4"
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
    platform      = "platform"
  }
}

variable "vps_host" {
  description = "VPS host IP for DNS records (set via TF_VAR_vps_host in Atlantis)"
  type        = string
  default     = ""
}
