# L3 Data Layer Variables

variable "kubeconfig_path" {
  description = "Path to kubeconfig file (set via TF_VAR_kubeconfig_path in Atlantis)"
  type        = string
  default     = ""
}

# R2 configuration for terraform_remote_state
variable "r2_bucket" {
  description = "R2 bucket name for Terraform state"
  type        = string
  default     = "zitian-infra"
}

variable "r2_account_id" {
  description = "Cloudflare account ID for R2"
  type        = string
  default     = "" # Set via TF_VAR_r2_account_id or Atlantis env
}
