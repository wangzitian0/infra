variable "vps_host" {
  description = "Public IP or DNS name of the VPS where k3s will be installed"
  type        = string
}

variable "vps_user" {
  description = "SSH user on the VPS"
  type        = string
  default     = "root"
}

variable "ssh_port" {
  description = "SSH port on the VPS"
  type        = number
  default     = 22
}

variable "ssh_private_key" {
  description = "Private key used for SSH (contents of the key, not a path)"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "Logical name for this k3s cluster"
  type        = string
  default     = "truealpha-k3s"
}

variable "api_endpoint" {
  description = "Public address used to reach the k3s API server; defaults to vps_host"
  type        = string
  default     = null
}

variable "k3s_channel" {
  description = "Release channel passed to the k3s installer (stable, latest, etc.)"
  type        = string
  default     = "stable"
}

variable "k3s_version" {
  description = "Optional explicit k3s version (e.g., v1.28.7+k3s1). Leave empty to follow the channel."
  type        = string
  default     = ""
}

variable "disable_components" {
  description = "Components to disable in k3s (passed as --disable flags)"
  type        = list(string)
  default     = ["traefik"]
}
