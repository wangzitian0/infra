variable "zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "domain" {
  description = "Root domain name"
  type        = string
}

variable "environment" {
  description = "Environment (dev/test/staging/prod)"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "vps_ips" {
  description = "List of VPS IP addresses"
  type        = list(string)
}

variable "enable_waf" {
  description = "Enable WAF rules"
  type        = bool
  default     = true
}

variable "enable_rate_limiting" {
  description = "Enable rate limiting"
  type        = bool
  default     = true
}
