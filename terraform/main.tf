# Infra Orchestration (L1-L4)

# L1: Bootstrap (K3s + Atlantis CI Foundation)
# 零依赖层，密钥来自 GitHub Secrets
module "nodep" {
  source = "./1.nodep"

  vps_host           = var.vps_host
  vps_user           = var.vps_user
  ssh_port           = var.ssh_port
  ssh_private_key    = var.ssh_private_key
  cluster_name       = var.cluster_name
  api_endpoint       = local.api_endpoint
  k3s_channel        = var.k3s_channel
  k3s_version        = var.k3s_version
  disable_components = var.disable_components
  kubeconfig_path    = local.kubeconfig_path

  # Atlantis (CI Foundation)
  github_token                = var.github_token
  atlantis_webhook_secret     = var.atlantis_webhook_secret
  github_app_id               = var.github_app_id
  github_app_key              = var.github_app_key
  aws_access_key_id           = var.aws_access_key_id
  aws_secret_access_key       = var.aws_secret_access_key
  r2_bucket                   = var.r2_bucket
  r2_account_id               = var.r2_account_id
  base_domain                 = var.base_domain
  cloudflare_api_token        = var.cloudflare_api_token
  cloudflare_zone_id          = var.cloudflare_zone_id
  infisical_postgres_password = var.infisical_postgres_password
}


# L2: Platform (Moved to layer2-platform)
# Use terraform/layer2-platform for Platform resources
# Resources migrated via scripts/migrate-state.sh

# L3: Data (数据面 - 业务数据库)
# module "data" {
#   source = "./3.data"
#   depends_on = [module.platform]
# }

# L4: Insight (可观测性 - 日志/监控/告警/分析)
# module "insight" {
#   source = "./4.insight"
#   depends_on = [module.data]
# }
