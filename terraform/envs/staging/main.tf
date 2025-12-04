module "root" {
  source = "../.."

  environment             = var.environment
  project_name            = var.project_name
  domain                  = var.domain
  cloudflare_api_token    = var.cloudflare_api_token
  cloudflare_zone_id      = var.cloudflare_zone_id
  vps_ip                  = var.vps_ip
  vps_count               = var.vps_count
  vps_size                = var.vps_size
  vps_region              = var.vps_region
  ssh_keys                = var.ssh_keys
  tags                    = var.tags

  # Dokploy / Infisical bootstrap
  enable_dokploy_infisical   = var.enable_dokploy_infisical
  dokploy_api_url            = var.dokploy_api_url
  dokploy_api_key            = var.dokploy_api_key
  dokploy_organization_id    = var.dokploy_organization_id
  dokploy_project_name       = var.dokploy_project_name
  dokploy_environment_name   = var.dokploy_environment_name
  dokploy_compose_name       = var.dokploy_compose_name
  dokploy_compose_file       = var.dokploy_compose_file
  dokploy_server_name        = var.dokploy_server_name
  dokploy_server_username    = var.dokploy_server_username
  dokploy_server_port        = var.dokploy_server_port
  dokploy_server_type        = var.dokploy_server_type
  dokploy_ssh_key_name       = var.dokploy_ssh_key_name
  dokploy_ssh_public_key     = var.dokploy_ssh_public_key
  dokploy_ssh_private_key    = var.dokploy_ssh_private_key
  infisical_host             = var.infisical_host
  infisical_encryption_key   = var.infisical_encryption_key
  infisical_admin_email      = var.infisical_admin_email
  infisical_admin_password   = var.infisical_admin_password
  infisical_license_key      = var.infisical_license_key
  infisical_postgres_user    = var.infisical_postgres_user
  infisical_postgres_password= var.infisical_postgres_password
  infisical_postgres_db      = var.infisical_postgres_db
  infisical_redis_password   = var.infisical_redis_password
  infisical_traefik_network  = var.infisical_traefik_network
  dokploy_force_redeploy_token = var.dokploy_force_redeploy_token
}

variable "environment" {}
variable "project_name" {}
variable "domain" {}
variable "cloudflare_api_token" {}
variable "cloudflare_zone_id" {}
variable "vps_ip" {}
variable "vps_count" {}
variable "vps_size" {}
variable "vps_region" {}
variable "ssh_keys" {}
variable "tags" {}
variable "enable_dokploy_infisical" {}
variable "dokploy_api_url" {}
variable "dokploy_api_key" {}
variable "dokploy_organization_id" {}
variable "dokploy_project_name" {}
variable "dokploy_environment_name" {}
variable "dokploy_compose_name" {}
variable "dokploy_compose_file" {}
variable "dokploy_server_name" {}
variable "dokploy_server_username" {}
variable "dokploy_server_port" {}
variable "dokploy_server_type" {}
variable "dokploy_ssh_key_name" {}
variable "dokploy_ssh_public_key" {}
variable "dokploy_ssh_private_key" {}
variable "infisical_host" {}
variable "infisical_encryption_key" {}
variable "infisical_admin_email" {}
variable "infisical_admin_password" {}
variable "infisical_license_key" {}
variable "infisical_postgres_user" {}
variable "infisical_postgres_password" {}
variable "infisical_postgres_db" {}
variable "infisical_redis_password" {}
variable "infisical_traefik_network" {}
variable "dokploy_force_redeploy_token" {}

output "vps_ips" {
  value = module.root.vps_ips
}

output "dns_records" {
  value = module.root.dns_records
}
