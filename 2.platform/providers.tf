# L2 Platform Provider Configuration
#
# When running in Atlantis (in-cluster), kubeconfig_path can be empty.
# Providers will auto-detect in-cluster ServiceAccount credentials.
# When running locally, set TF_VAR_kubeconfig_path to point to your kubeconfig file.

provider "kubernetes" {
  config_path = var.kubeconfig_path != "" ? var.kubeconfig_path : null
  # When config_path is null, provider uses in-cluster config automatically
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path != "" ? var.kubeconfig_path : null
  }
}

provider "kubectl" {
  config_path      = var.kubeconfig_path != "" ? var.kubeconfig_path : null
  load_config_file = var.kubeconfig_path != ""
}

# Cloudflare provider for DNS records (e.g., Casdoor)
provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Vault provider for database secrets engine configuration
# Uses root token for now; can migrate to Kubernetes auth later
provider "vault" {
  address         = var.vault_address
  token           = var.vault_root_token
  skip_tls_verify = true
}

# Cloudflare zone data source for internal domain (used by Casdoor DNS)
data "cloudflare_zone" "internal" {
  name = local.internal_domain
}

# RestAPI provider for Casdoor management
# Uses casdoor-builtin-app credentials (M2M) to manage resources via API
# Docs: https://registry.terraform.io/providers/Mastercard/restapi/latest/docs
provider "restapi" {
  uri                  = "https://sso.${local.internal_domain}"
  debug                = true
  write_returns_object = true
  username             = "casdoor-builtin-app"
  password             = var.casdoor_admin_password
  id_attribute         = "name" # Casdoor uses 'name' as the primary key in JSON
}
// trigger l2

