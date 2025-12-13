# L3 Data Layer Provider Configuration
#
# Providers: kubernetes, helm
# Password: Read from L2 via terraform_remote_state (no Vault provider needed!)
#
# Architecture decision:
# Instead of L3 requiring Vault token to read password,
# L3 reads password from L2's terraform state via terraform_remote_state.
# This simplifies the auth chain and eliminates env var passing issues.

# When running in Atlantis (in-cluster), kubeconfig_path can be empty.
# Providers will auto-detect in-cluster ServiceAccount credentials.

provider "kubernetes" {
  config_path = var.kubeconfig_path != "" ? var.kubeconfig_path : null
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path != "" ? var.kubeconfig_path : null
  }
}
