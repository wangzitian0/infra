# L2 Platform Provider Configuration
#
# When running in Atlantis (in-cluster), kubeconfig_path can be empty.
# Providers will auto-detect in-cluster ServiceAccount credentials.
# When running locally, set TF_VAR_kubeconfig_path to point to your kubeconfig file.
#
# Note: PostgreSQL and ClickHouse providers removed (Issue #336)
# L2 no longer directly connects to databases. Use Vault dynamic credentials in L4.

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

# Vault provider for secrets engine configuration
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

# =============================================================================
# Temporary Providers for Resource Cleanup (PR #336)
# These providers are only needed to destroy old resources moved to L3
# TODO: Remove after old database resources are destroyed from L2 state
# =============================================================================

# ClickHouse provider (temporary - for destroying old clickhousedbops resources)
provider "clickhousedbops" {
  host        = "clickhouse.data-staging.svc.cluster.local"
  port        = 9000
  username    = "default"
  password    = "dummy" # Not used during destroy, but required by provider schema
  protocol    = "native"
  auth_config = {
    username = "default"
    password = "dummy"
  }
}

# PostgreSQL provider (temporary - for destroying old postgresql resources)
provider "postgresql" {
  host            = "postgresql.data-staging.svc.cluster.local"
  port            = 5432
  username        = "postgres"
  password        = "dummy" # Not used during destroy, but required by provider schema
  sslmode         = "disable"
  connect_timeout = 15
}
