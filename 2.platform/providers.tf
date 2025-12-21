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

# NOTE: RestAPI provider is configured in 90.provider_restapi.tf

provider "clickhousedbops" {
  host     = "clickhouse.data-staging.svc.cluster.local" # Default to staging for L2 admin tasks
  port     = 8123
  protocol = "http"

  auth_config = {
    strategy = "basicauth"
    username = "default"
    password = random_password.l3_clickhouse.result
  }
}
