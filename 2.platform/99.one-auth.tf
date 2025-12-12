# One-Auth: Gate L2 service access behind a single SSO entrypoint.
#
# IMPORTANT:
# - Terraform does NOT guarantee file ordering; use explicit dependencies.
# - Use `enable_one_auth=false` to deploy/verify base services first.
# - Flip `enable_one_auth=true` only after you can reach all L2 URLs.

locals {
  # "SSO Gate" is implemented as a Traefik middleware (forwardAuth) backed by OAuth2-Proxy.
  one_auth_enabled = var.enable_one_auth && local.oauth2_proxy_enabled
}

# Basic prechecks to avoid locking yourself out due to missing prerequisites.
resource "terraform_data" "one_auth_precheck" {
  input = {
    enabled = local.one_auth_enabled
  }

  lifecycle {
    precondition {
      condition     = !var.enable_one_auth || local.oauth2_proxy_enabled
      error_message = "enable_one_auth=true requires OAuth2-Proxy to be enabled (set github_oauth_client_id/github_oauth_client_secret)."
    }

    precondition {
      condition     = !var.enable_one_auth || length(kubernetes_manifest.oauth2_auth_middleware) == 1
      error_message = "enable_one_auth=true requires the Traefik oauth2-proxy middleware to exist."
    }
  }
}

output "one_auth_enabled" {
  value       = local.one_auth_enabled
  description = "Whether L2 ingress SSO gate is enabled (Traefik middleware)."
}

