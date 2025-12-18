variable "environment" {
  description = "Deployment environment (staging/prod)"
  type        = string
  default     = "staging"
}

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

variable "namespaces" {
  description = "Map of namespace names"
  type        = map(string)
  default = {
    platform = "platform"
    kubero   = "kubero"
  }
}

# ============================================================
# Vault Configuration (for reading secrets)
# ============================================================

variable "vault_root_token" {
  description = "Vault root token (set via TF_VAR_vault_root_token in Atlantis)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "vault_address" {
  description = "Vault server address."
  type        = string
  default     = "http://vault.platform.svc.cluster.local:8200"
}

variable "vault_kv_mount" {
  description = "Vault KV secrets engine mount path."
  type        = string
  default     = "secret"
}
