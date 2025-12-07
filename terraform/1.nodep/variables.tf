variable "vps_host" {}
variable "vps_user" {}
variable "ssh_port" {}
variable "ssh_private_key" {}
variable "cluster_name" {}
variable "api_endpoint" {}
variable "k3s_channel" {}
variable "k3s_version" {}
variable "disable_components" {}
variable "kubeconfig_path" {}

# Atlantis Variables (L1 CI Foundation)
variable "github_org" {
  default = "wangzitian0"
}
variable "github_user" {
  default = "wangzitian0"
}
variable "github_token" {
  sensitive = true
  default   = "" # Not needed when using GitHub App
}
variable "atlantis_webhook_secret" {
  sensitive = true
}
# GitHub App Configuration (preferred over PAT)
variable "github_app_id" {
  default = "" # Set to App ID to enable GitHub App auth
}
variable "github_app_key" {
  sensitive = true
  default   = "" # PEM-encoded private key
}
variable "aws_access_key_id" {
  sensitive = true
}
variable "aws_secret_access_key" {
  sensitive = true
}
variable "r2_bucket" {}
variable "r2_account_id" {}
variable "base_domain" {}
variable "cloudflare_api_token" {
  sensitive = true
}
variable "cloudflare_zone_id" {}
variable "infisical_postgres_password" {
  sensitive = true
}

