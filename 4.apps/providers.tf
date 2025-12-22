provider "kubernetes" {
  config_path = var.kubeconfig_path != "" ? var.kubeconfig_path : null
  # When config_path is null, provider uses in-cluster config automatically
}

# Helm provider for SigNoz and other Helm charts
provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path != "" ? var.kubeconfig_path : null
  }
}

# Vault provider for reading secrets
provider "vault" {
  address         = var.vault_address
  token           = var.vault_root_token
  skip_tls_verify = true
}

provider "kubectl" {
  config_path      = var.kubeconfig_path != "" ? var.kubeconfig_path : null
  load_config_file = var.kubeconfig_path != ""
}
