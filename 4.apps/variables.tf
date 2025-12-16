variable "kubeconfig_path" {
  description = "Path to kubeconfig file (set via TF_VAR_kubeconfig_path in Atlantis)"
  type        = string
  default     = ""
}

variable "base_domain" {
  description = "Base domain for business/production services"
  type        = string
  default     = "truealpha.club"
}

variable "internal_domain" {
  description = "Internal/infra domain for platform services (dashboard, vault, kubero, auth)"
  type        = string
  default     = "zitian.party"
}

variable "enable_portal_sso_gate" {
  description = "Enable Casdoor-based SSO gate for platform portals (Vault/Dashboard/Kubero) via OAuth2-Proxy."
  type        = bool
  default     = false
}

variable "kubero_ui_image_tag" {
  description = "Kubero UI image tag. Pin this to a fixed version for reproducible deploys (avoid 'latest')."
  type        = string
  default     = "latest"
}

variable "kubero_ui_image_pull_policy" {
  description = "Kubero UI image pull policy. Use IfNotPresent for stability; avoid Always unless debugging."
  type        = string
  default     = "IfNotPresent"
}
