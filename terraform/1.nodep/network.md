# Network & Domain SSOT

Secondary domain and URL Single Source of Truth.

## Domains

| Service | Subdomain | Full URL | Managed By |
|---------|-----------|----------|------------|
| Atlantis | `atlantis` | `https://atlantis.${BASE_DOMAIN}` | L1 (Nodep) |
| K3s API | (root/ip) | `https://${VPS_HOST}:6443` | L1 (Nodep) |
| Kubero UI | `api` | `https://api-${DOMAIN_PREFIX}.${BASE_DOMAIN}` | L2 (Networking) |
| Infisical | `cloud` | `https://cloud-${DOMAIN_PREFIX}.${BASE_DOMAIN}` | L2 (Networking) |
| App Frontend | (root) | `https://${DOMAIN_PREFIX}.${BASE_DOMAIN}` | L2 (Networking) |
| App Backend | `api` | `https://api-${DOMAIN_PREFIX}.${BASE_DOMAIN}` | L2 (Networking) |

> **Note**: Base domain is defined in `terraform.tfvars` via `base_domain` variable.
