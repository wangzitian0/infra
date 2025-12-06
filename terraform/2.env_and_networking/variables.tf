variable "kubeconfig_path" {}
variable "env_prefix" {}
variable "base_domain" {}
variable "infisical_chart_version" {}
variable "infisical_image_tag" {}
variable "infisical_postgres_password" {}
variable "infisical_postgres_storage" {}
variable "namespaces" {
  type = map(string)
}

variable "vps_host" {} # Needed for A record IF not managed by L1 (Wait, L1 now manages Atlantis DNS)
# Actually, L2 might still need vps_host for other things, but Cloudflare secrets are moving to L1.
