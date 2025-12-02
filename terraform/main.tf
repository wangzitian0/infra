# Main Terraform Configuration

# VPS Module
module "vps" {
  source = "./modules/vps"
  count  = var.vps_count

  environment  = var.environment
  project_name = var.project_name
  instance_name = "${var.project_name}-${var.environment}-${count.index + 1}"
  size         = var.vps_size
  region       = var.vps_region
  ssh_keys     = var.ssh_keys
  tags         = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# Cloudflare Module
module "cloudflare" {
  source = "./modules/cloudflare"

  zone_id      = var.cloudflare_zone_id
  domain       = var.domain
  environment  = var.environment
  project_name = var.project_name
  vps_ips      = module.vps[*].public_ip
}

# Database Module (optional)
module "database" {
  source = "./modules/database"
  count  = var.enable_managed_database ? 1 : 0

  environment  = var.environment
  project_name = var.project_name
  size         = var.database_size
  region       = var.vps_region
  tags         = var.tags
}

# Monitoring Module (optional)
module "monitoring" {
  source = "./modules/monitoring"
  count  = var.enable_monitoring ? 1 : 0

  environment  = var.environment
  project_name = var.project_name
  vps_ips      = module.vps[*].public_ip
}
