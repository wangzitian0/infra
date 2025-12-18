# Vault Kubernetes Auth Backend Configuration
# Enables pods to authenticate with Vault using their ServiceAccount tokens.

resource "vault_auth_backend" "kubernetes" {
  type = "kubernetes"
  path = "kubernetes"
}

resource "vault_kubernetes_auth_backend_config" "config" {
  backend                = vault_auth_backend.kubernetes.path
  kubernetes_host        = var.kubernetes_host
  kubernetes_ca_cert     = var.kubernetes_ca_cert != "" ? base64decode(var.kubernetes_ca_cert) : null
  disable_iss_validation = true
}
