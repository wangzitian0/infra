# Terraform Modules

Shared Terraform modules used across multiple layers (L2, L3, L4).

## Available Modules

### [vault-config](./vault-config/)

Single Source of Truth (SSOT) for Vault path configurations.

**Outputs:**
- `vault_kv_mount` - KV v2 mount path ("secret")
- `vault_db_secrets` - Map of DB type → secret name
- `vault_secret_paths` - Full API paths for documentation

**Usage:**
```hcl
module "vault_config" {
  source = "../modules/vault-config"
}

resource "vault_kv_secret_v2" "postgres" {
  mount = module.vault_config.vault_kv_mount
  name  = module.vault_config.vault_db_secrets["postgres"]
}
```

## Issue Reference

- Issue #301: Vault path hardcoding elimination

---
*Last updated: 2025-12-20 (Initial creation)*
