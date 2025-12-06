# Network & Domain SSOT

## 0. DNS Architecture

**Cloudflare Wildcard DNS + Ingress Routing**:
- `*.truealpha.club` → VPS IP (proxied, orange cloud)
- `@` (root) → VPS IP (proxied)
- `i-k3s` → VPS IP (DNS-only, grey cloud, for port 6443)

All HTTP/HTTPS (80/443) services route through Nginx Ingress Controller.
Each service defines its own Ingress with specific `host` rule.

## 1. 变量定义 (Definitions)

| Variable | Description | Example Value | Source |
|----------|-------------|---------------|--------|
| `${BASE_DOMAIN}` | 基础域名 | `truealpha.club` | `terraform.tfvars` |
| `${VPS_HOST}` | 基础 IP | `1.2.3.4` | `terraform.tfvars` (for context) |
| `${ENV_PREFIX}` | 环境前缀 | `x-staging` | `staging.tfvars` |

## 2. 命名模式 (Patterns)

### A. 内部服务 (Internal Service)
*   **Prefix**: `i-`
*   **Pattern**: `i-{service}.${BASE_DOMAIN}`
*   **Example**: `i-atlantis.example.com`

### B. 环境服务 (Environmental Service)
*   **Prefix**: `x-`
*   **Pattern**: `x-{env}-{service}.${BASE_DOMAIN}` (equivalent to `${DOMAIN_PREFIX}-{service}.${BASE_DOMAIN}`)
*   **Example** (Staging): `x-staging-api.example.com`

## 3. 服务列表 (Service List)

| Category | Service | `{service}` Name | Pattern | Full Example URL | Managed By |
|----------|---------|------------------|---------|------------------|------------|
| **Global** | Atlantis | `atlantis` | **A** | `https://i-atlantis.${BASE_DOMAIN}` | L1 (Nodep) |
| **Global** | K3s API | `k3s` | **A** | `https://i-k3s.${BASE_DOMAIN}` | L1 (Nodep) |
| **Env** | Kubero UI | `api` | **B** | `https://${DOMAIN_PREFIX}-api.${BASE_DOMAIN}` | L2 (Networking) |
| **Env** | Kubero Backend | `api` | **B** | `https://${DOMAIN_PREFIX}-api.${BASE_DOMAIN}` | L2 (Networking) |
| **Env** | Infisical | `cloud` | **B** | `https://${DOMAIN_PREFIX}-cloud.${BASE_DOMAIN}` | L2 (Networking) |
| **Env** | SigNoz | `signoz` | **B** | `https://${DOMAIN_PREFIX}-signoz.${BASE_DOMAIN}` | L2 (Observability) |
| **Env** | PostHog | `posthog` | **B** | `https://${DOMAIN_PREFIX}-posthog.${BASE_DOMAIN}` | L2 (Observability) |
| **App** | Frontend | (root) | **B***| `https://${DOMAIN_PREFIX}.${BASE_DOMAIN}` | L2 (Networking) |

> *Frontend uses the prefix directly as the subdomain in the environment pattern.
