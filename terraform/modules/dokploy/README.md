# Dokploy Infisical Bootstrap (via API)

This module calls `scripts/dokploy/bootstrap_infisical.sh` during `terraform apply` to:

1. Resolve/ensure Dokploy organization → SSH key → server → project → environment.
2. Upload the Infisical compose template (envsubst'd) to Dokploy.
3. Trigger a deploy.

Inputs are passed as environment variables to the script; secrets stay out of state (only the compose template hash and a force token are stored as triggers).

Usage (excerpt):

```hcl
module "dokploy" {
  source              = "../../modules/dokploy"
  enable_infisical    = true
  api_key             = var.dokploy_api_key
  server_ip           = var.vps_ip
  ssh_public_key      = var.dokploy_ssh_public_key
  ssh_private_key     = var.dokploy_ssh_private_key
  infisical_encryption_key = var.infisical_encryption_key
  infisical_admin_email    = var.infisical_admin_email
  infisical_admin_password = var.infisical_admin_password
  infisical_postgres_user  = var.infisical_postgres_user
  infisical_postgres_password = var.infisical_postgres_password
}
```

Set `force_redeploy_token` to a new value when you rotate secrets to force a redeploy without touching the template.
