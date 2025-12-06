# Network & Domain SSOT

Secondary domain and URL Single Source of Truth.

## Domains

| Service | Subdomain | Full URL | Managed By |
|---------|-----------|----------|------------|
| Atlantis | `atlantis` | `https://atlantis.${BASE_DOMAIN}` | L1 (Nodep) |
| K3s API | (root/ip) | `https://${VPS_HOST}:6443` | L1 (Nodep) |

> **Note**: Base domain is defined in `terraform.tfvars` via `base_domain` variable.
