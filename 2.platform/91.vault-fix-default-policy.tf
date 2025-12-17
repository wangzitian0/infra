locals {
  # Default policy content allowing OIDC auth flows for unauthenticated users
  # Used by vault_generic_endpoint below to force-update the built-in 'default' policy.
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

# Use vault_generic_endpoint to manage the built-in 'default' policy.
# This uses the generic Vault API resource, bypassing potential limitation 
# of vault_policy resource regarding built-in policies.
resource "vault_generic_endpoint" "default_policy" {
  count = local.portal_sso_gate_enabled ? 1 : 0

  # API Endpoint for the Default ACL Policy
  # Writes to: PUT /v1/sys/policies/acl/default
  path = "sys/policies/acl/default"

  # Payload (HCL policy wrapped in JSON)
  data_json = local.default_policy_json

  # PROTECT THE DEFAULT POLICY: Do not delete it if this resource is destroyed.
  # This merely stops managing it, leaving it in its last state.
  disable_delete = true
}
