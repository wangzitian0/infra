# 1. Generate random secrets
resource "random_id" "kubero_session_secret" {
  byte_length = 32
}

resource "random_id" "kubero_webhook_secret" {
  byte_length = 32
}

# 2. Store secrets in Vault KV
resource "vault_kv_secret_v2" "kubero" {
  mount               = vault_mount.kv.path
  name                = "data/kubero"
  delete_all_versions = true

  data_json = jsonencode({
    KUBERO_WEBHOOK_SECRET = random_id.kubero_webhook_secret.hex
    KUBERO_SESSION_KEY    = random_id.kubero_session_secret.hex
  })
}

# 2. Define Policy for Kubero to read its secrets
resource "vault_policy" "kubero" {
  name = "kubero"

  policy = <<-EOT
    path "secret/data/data/kubero" {
      capabilities = ["read"]
    }
  EOT
}

# 3. Define Kubernetes Auth Role for Kubero
resource "vault_kubernetes_auth_backend_role" "kubero" {
  backend                          = vault_auth_backend.kubernetes.path
  role_name                        = "kubero"
  bound_service_account_names      = ["kubero"]
  bound_service_account_namespaces = ["kubero-*"]
  token_policies                   = ["kubero"]
  token_ttl                        = 3600
}
