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

# Dokploy API bootstrap (Infisical)
module "dokploy" {
  source = "./modules/dokploy"

  enable_infisical        = var.enable_dokploy_infisical
  api_url                 = var.dokploy_api_url
  api_key                 = var.dokploy_api_key
  organization_id         = var.dokploy_organization_id
  project_name            = var.dokploy_project_name
  environment_name        = var.dokploy_environment_name
  compose_name            = var.dokploy_compose_name
  compose_file            = var.dokploy_compose_file
  compose_app_name        = "${var.project_name}-${var.environment}-infisical"
  server_name             = var.dokploy_server_name
  server_ip               = var.vps_ip
  server_username         = var.dokploy_server_username
  server_port             = var.dokploy_server_port
  server_type             = var.dokploy_server_type
  ssh_key_name            = var.dokploy_ssh_key_name
  ssh_public_key          = var.dokploy_ssh_public_key
  ssh_private_key         = var.dokploy_ssh_private_key
  infisical_host          = var.infisical_host
  infisical_encryption_key = var.infisical_encryption_key
  infisical_admin_email    = var.infisical_admin_email
  infisical_admin_password = var.infisical_admin_password
  infisical_license_key    = var.infisical_license_key
  infisical_postgres_user  = var.infisical_postgres_user
  infisical_postgres_password = var.infisical_postgres_password
  infisical_postgres_db    = var.infisical_postgres_db
  infisical_redis_password = var.infisical_redis_password
  infisical_traefik_network = var.infisical_traefik_network
  force_redeploy_token     = var.dokploy_force_redeploy_token
}
