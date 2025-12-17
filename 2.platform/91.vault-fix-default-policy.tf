locals {
  # Default policy content allowing OIDC auth flows for unauthenticated users
  # Used by null_resource below to force-update the built-in 'default' policy.
  default_policy_json = jsonencode({
    policy = <<-EOT
      # Basic self-service token capabilities
      path "auth/token/lookup-self" { capabilities = ["read"] }
      path "auth/token/revoke-self" { capabilities = ["update"] }
      path "sys/capabilities-self" { capabilities = ["update"] }
      path "auth/token/renew-self" { capabilities = ["update"] }
      path "sys/leases/renew" { capabilities = ["update"] }
      path "sys/leases/lookup" { capabilities = ["list", "read"] }
      
      # OIDC Public Endpoints - REQUIRED FOR UI LOGIN
      # "auth/oidc/oidc/auth_url" is required for the UI to generate the auth link
      path "auth/oidc/oidc/auth_url" { capabilities = ["read", "update"] }
      
      # "auth/oidc/role/*" is required to read role config (redirect_uris)
      path "auth/oidc/role/*" { capabilities = ["read"] }
      
      # General visibility
      path "sys/auth" { capabilities = ["read"] }
      path "sys/internal/ui/mounts/*" { capabilities = ["read"] }
    EOT
  })
}

# Force update default policy using curl because terraform vault_policy resource
# fails to update the built-in 'default' policy.
resource "null_resource" "force_default_policy_update" {
  count = local.portal_sso_gate_enabled ? 1 : 0

  triggers = {
    policy_hash = md5(local.default_policy_json)
  }

  provisioner "local-exec" {
    # Using 'curl' to directly PUT the policy content to Vault API
    # -k: Insecure (internal cluster traffic might use self-signed if HTTPS, though usually HTTP)
    # -S -s: Silent but show errors
    command = "curl -k -S -s -X PUT -H \"X-Vault-Token: $VAULT_TOKEN\" -d '$POLICY_JSON' $VAULT_ADDR/v1/sys/policies/acl/default"

    environment = {
      VAULT_ADDR  = var.vault_address
      VAULT_TOKEN = var.vault_root_token
      POLICY_JSON = local.default_policy_json
    }
  }
}
