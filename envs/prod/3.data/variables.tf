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

variable "clickhouse_host" {
  description = "ClickHouse host address. Defaults to in-cluster DNS; override to localhost for port-forward."
  type        = string
  default     = ""
}

# =============================================================================
# R2 Backend Variables (for terraform_remote_state to read L2 outputs)
# Passed by Atlantis via TF_VAR_* from L1
# =============================================================================
variable "r2_bucket" {
  description = "R2 bucket name for Terraform state"
  type        = string
}

variable "r2_account_id" {
  description = "Cloudflare R2 account ID"
  type        = string
}
