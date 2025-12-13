# L3 Data Layer Variables

variable "kubeconfig_path" {
  description = "Path to kubeconfig file (set via TF_VAR_kubeconfig_path in Atlantis)"
  type        = string
  default     = ""
}

variable "vault_root_token" {
  description = "Vault root token for reading secrets (from 1Password via GitHub Secret)"
  type        = string
  sensitive   = true
  default     = "" # Default for plan; Atlantis sets via TF_VAR_vault_root_token
}
