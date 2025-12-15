# L3 Data Layer Variables

variable "kubeconfig_path" {
  description = "Path to kubeconfig file (set via TF_VAR_kubeconfig_path in Atlantis)"
  type        = string
  default     = ""
}

variable "vault_address" {
  description = "Vault server address. Defaults to in-cluster DNS; override to http://localhost:8200 for port-forward."
  type        = string
  default     = "http://vault.platform.svc.cluster.local:8200"
}

variable "vault_root_token" {
  description = "Vault root token for reading secrets (from 1Password via GitHub Secret)"
  type        = string
  sensitive   = true
  default     = "" # Default for plan; Atlantis sets via TF_VAR_vault_root_token

  validation {
    condition     = var.vault_root_token == "" || length(var.vault_root_token) > 20
    error_message = "vault_root_token must be a valid Vault token (or empty for plan-only)."
  }
}

