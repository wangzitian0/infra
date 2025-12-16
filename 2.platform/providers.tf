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
// trigger l2

# Casdoor REST API provider for managing OIDC applications
# Uses admin credentials for M2M authentication
provider "restapi" {
  alias                = "casdoor"
  uri                  = "https://sso.${var.internal_domain}"
  write_returns_object = true

  headers = {
    Content-Type = "application/json"
  }

  # Skip create if object exists (for idempotency)
  create_returns_object = true
}
