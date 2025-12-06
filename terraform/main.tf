# Infra Orchestration (L1-L5)

# L1: Bootstrap (K3s + Atlantis CI Foundation)
module "nodep" {
  source = "./1.nodep"
  count  = var.enable_infra ? 1 : 0

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
  github_token            = var.github_token
  atlantis_webhook_secret = var.atlantis_webhook_secret
  github_app_id           = var.github_app_id
  github_app_key          = var.github_app_key
  aws_access_key_id       = "" # Set via env: AWS_ACCESS_KEY_ID
  aws_secret_access_key   = "" # Set via env: AWS_SECRET_ACCESS_KEY  
  r2_bucket               = var.r2_bucket
  r2_account_id           = var.r2_account_id
  base_domain             = var.base_domain
  cloudflare_api_token    = var.cloudflare_api_token
  cloudflare_zone_id      = var.cloudflare_zone_id
}


# L2: Environment & Networking (Secrets + Platform Subs)
module "env_and_networking" {
  source = "./2.env_and_networking"
  count  = var.enable_infra ? 1 : 0

  infisical_chart_version     = var.infisical_chart_version
  infisical_image_tag         = var.infisical_image_tag
  infisical_postgres_password = var.infisical_postgres_password
  infisical_postgres_storage  = var.infisical_postgres_storage
  env_prefix                  = var.env_prefix
  base_domain                 = var.base_domain
  namespaces                  = local.namespaces
  kubeconfig_path             = local.kubeconfig_path

  # cloudflare_api_token = var.cloudflare_api_token # Moved to L1
  # cloudflare_zone_id   = var.cloudflare_zone_id   # Moved to L1
  # vps_host             = var.vps_host             # Keeping if L2 needs it, but removing passed arg if defined in L2 variables.tf as removed.
  # Checking L2 variables.tf update: I removed vps_host from L2 variables?
  # Wait, the previous replacement text for L2 variables.tf kept vps_host.
  # "variable "vps_host" {} # Needed for A record IF not managed by L1..."
  vps_host             = var.vps_host

  depends_on = [module.nodep]
}

# L4: Data Services
# module "data" {
#   source = "./3.data"
#   depends_on = [module.platform]
# }

# L5: Insight
# module "insight" {
#   source = "./4.insight"
#   depends_on = [module.data]
# }
