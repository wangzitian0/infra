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
  vps_ips      = var.vps_count > 0 ? module.vps[*].public_ip : [var.vps_ip]
}

# VPS Bootstrap Module (optional, for automated setup)
module "vps_bootstrap" {
  source = "./modules/vps-bootstrap"
  count  = var.enable_vps_bootstrap ? 1 : 0

  vps_ip          = var.vps_ip
  ssh_user        = var.ssh_user
  ssh_private_key = var.ssh_private_key
}

# Note: Database and Monitoring modules removed as they are managed via Docker Compose
# See compose/base.yml for database services (Neo4j, PostgreSQL, Redis)
