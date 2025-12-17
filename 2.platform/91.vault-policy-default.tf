# Update the built-in 'default' policy to allow OIDC UI access
# The default policy is attached to all tokens, including unauthenticated ones.
# 
<<<<<<< HEAD
# Issue: Vault UI needs to read OIDC role config (redirect_uris) before login to construct the auth URL.
# Without this, "Sign in with OIDC" fails with "permission denied" when fetching role.
=======
# Issue: Vault needs to allow unauthenticated access to OIDC config endpoints 
# for the login flow to work (e.g. fetching auth_url, checking requirements).
>>>>>>> origin/main

resource "vault_policy" "default" {
  name = "default"

  policy = <<-EOT
    # Allow tokens to look up their own properties
    path "auth/token/lookup-self" {
        capabilities = ["read"]
    }

    # Allow tokens to revoke themselves
    path "auth/token/revoke-self" {
        capabilities = ["update"]
    }

    # Allow tokens to check their own capabilities
    path "sys/capabilities-self" {
        capabilities = ["update"]
    }

    # Allow tokens to renew themselves
    path "auth/token/renew-self" {
        capabilities = ["update"]
    }

    # Allow tokens to look up their own entity
    path "sys/leases/renew" {
        capabilities = ["update"]
    }
    
    # Allow tokens to look up their own lease
    path "sys/leases/lookup" {
        capabilities = ["list", "read"]
    }

<<<<<<< HEAD
    # Allow reading OIDC auth config (Required for Vault UI OIDC Login)
    # This allows the UI to read redirect_uris and other public config from the role.
=======
    # Allow unauthenticated access to OIDC auth URL generation
    # Fixes: "permission denied" on "PUT .../oidc/auth_url"
    path "auth/oidc/oidc/auth_url" {
        capabilities = ["read", "update"]
    }

    # Allow reading OIDC role config (for UI to know redirect URIs)
>>>>>>> origin/main
    path "auth/oidc/role/*" {
        capabilities = ["read"]
    }

<<<<<<< HEAD
=======
    # Allow listing available auth methods (for UI)
    path "sys/auth" {
        capabilities = ["read"]
    }
    
>>>>>>> origin/main
    # Required for Vault UI to list mounts
    path "sys/internal/ui/mounts/*" {
        capabilities = ["read"]
    }
<<<<<<< HEAD

    # Allow listing available auth methods
    path "sys/auth" {
        capabilities = ["read"]
    }
=======
>>>>>>> origin/main
  EOT
}
