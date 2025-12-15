# L3 Data Layer Provider Configuration
#
# Providers: kubernetes, kubectl, helm, vault
# Vault access: Uses root token from GitHub Secret (for initial setup)
# Future: Migrate to Kubernetes auth method

# When running in Atlantis (in-cluster), kubeconfig_path can be empty.
# Providers will auto-detect in-cluster ServiceAccount credentials.

provider "kubernetes" {
  config_path = var.kubeconfig_path != "" ? var.kubeconfig_path : null
}

# kubectl provider for CRD-based resources (avoids plan-time API validation)
provider "kubectl" {
  config_path      = var.kubeconfig_path != "" ? var.kubeconfig_path : null
  load_config_file = var.kubeconfig_path != ""
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path != "" ? var.kubeconfig_path : null
  }
}

# Vault provider for reading secrets
# Address: configurable to support both in-cluster (Atlantis) and port-forward (GitHub runner)
provider "vault" {
  address = var.vault_address
  token   = var.vault_root_token

  # Skip TLS verification for internal communication
  skip_tls_verify = true
}
