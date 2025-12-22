# L3 Data Layer Provider Configuration
#
# Providers: kubernetes, kubectl, helm, vault, clickhousedbops
# 
# Architecture (after refactor - Issue #336):
# - L3 generates passwords locally
# - L3 stores passwords in Vault KV
# - L3 configures Vault Database Engine (PostgreSQL)
# - L3 manages ClickHouse users via clickhousedbops provider

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

# Vault provider for storing secrets and configuring database engine
# Address: configurable to support both in-cluster (Atlantis) and port-forward (GitHub runner)
provider "vault" {
  address = var.vault_address
  token   = var.vault_root_token

  # Skip TLS verification for internal communication
  skip_tls_verify = true
}

# ClickHouse database operations provider
# Used for managing users, databases, and privileges in ClickHouse
# Connects to ClickHouse HTTP interface using admin credentials (generated locally)
provider "clickhousedbops" {
  host     = var.clickhouse_host != "" ? var.clickhouse_host : "clickhouse.data-${terraform.workspace}.svc.cluster.local"
  port     = 8123
  protocol = "http"

  auth_config = {
    strategy = "basicauth"
    username = "default"
    password = random_password.clickhouse.result
  }
}
