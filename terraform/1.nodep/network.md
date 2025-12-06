# Network & Domain SSOT

Secondary domain and URL Single Source of Truth.

## Domains

| Scope | Service | Subdomain | Full URL | Managed By |
|-------|---------|-----------|----------|------------|
| **Global/Internal** | Atlantis | `x-atlantis` | `https://x-atlantis.${BASE_DOMAIN}` | L1 (Nodep) |
| **Global/Internal** | K3s API | `x-k3s` | `https://x-k3s.${BASE_DOMAIN}` | L1 (Nodep) |
| **Env (Staging/Prod)** | Infisical | `cloud` / `cloud-{prefix}` | `https://cloud[-${DOMAIN_PREFIX}].${BASE_DOMAIN}` | L2 (Networking) |
| **Env (Staging/Prod)** | Kubero UI | `api` / `api-{prefix}` | `https://api[-${DOMAIN_PREFIX}].${BASE_DOMAIN}` | L2 (Networking) |
| **Env (Staging/Prod)** | SigNoz | `signoz` / `signoz-{prefix}` | `https://signoz[-${DOMAIN_PREFIX}].${BASE_DOMAIN}` | L2 (Observability) |
| **Env (Staging/Prod)** | PostHog | `posthog` / `posthog-{prefix}` | `https://posthog[-${DOMAIN_PREFIX}].${BASE_DOMAIN}` | L2 (Observability) |
| **App** | Frontend | (root) / `{prefix}` | `https://[${DOMAIN_PREFIX}.]${BASE_DOMAIN}` | L2 (Networking) |
| **App** | Backend | `api` / `api-{prefix}` | `https://api[-${DOMAIN_PREFIX}].${BASE_DOMAIN}` | L2 (Networking) |

> **Note**: Base domain is defined in `terraform.tfvars` via `base_domain` variable.
