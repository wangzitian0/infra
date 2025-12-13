# L3 Data Layer Provider Configuration
#
# Providers: kubernetes, vault
# Vault access: Uses root token from GitHub Secret (for initial setup)
# Future: Migrate to Kubernetes auth method

# When running in Atlantis (in-cluster), kubeconfig_path can be empty.
# Providers will auto-detect in-cluster ServiceAccount credentials.

provider "kubernetes" {
  config_path = var.kubeconfig_path != "" ? var.kubeconfig_path : null
}

# Vault provider for reading secrets
# Address: internal K8s service DNS
provider "vault" {
  address = "http://vault.platform.svc.cluster.local:8200"
  token   = var.vault_root_token

  # Skip TLS verification for internal communication
  skip_tls_verify = true
}
