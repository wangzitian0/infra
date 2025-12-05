# Infra Orchestration (L1-L5)

# L1: Bootstrap
module "nodep" {
  source = "../1.nodep"

  vps_host          = var.vps_host
  vps_user          = var.vps_user
  ssh_port          = var.ssh_port
  ssh_private_key   = var.ssh_private_key
  cluster_name      = var.cluster_name
  api_endpoint      = local.api_endpoint
  k3s_channel       = var.k3s_channel
  k3s_version       = var.k3s_version
  disable_components = var.disable_components
}

# L2: Environment & Networking (Secrets + Platform Subs)
module "env_and_networking" {
  source = "../2.env_and_networking"

  infisical_chart_version     = var.infisical_chart_version
  infisical_image_tag         = var.infisical_image_tag
  infisical_postgres_password = var.infisical_postgres_password
  infisical_postgres_storage  = var.infisical_postgres_storage
  domain_prefix               = var.domain_prefix
  base_domain                 = var.base_domain
  namespaces                  = local.namespaces


  kubeconfig_path = local.kubeconfig_path


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
