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
  enable_managed_database = var.enable_managed_database
  enable_monitoring       = var.enable_monitoring
  tags                    = var.tags
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
variable "enable_managed_database" {}
variable "enable_monitoring" {}
variable "tags" {}

output "vps_ips" {
  value = module.root.vps_ips
}

output "dns_records" {
  value = module.root.dns_records
}
