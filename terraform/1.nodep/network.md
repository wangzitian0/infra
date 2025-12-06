# Network & Domain SSOT

## 1. 变量定义 (Definitions)

| Variable | Description | Example Value | Source |
|----------|-------------|---------------|--------|
| `${BASE_DOMAIN}` | 基础域名 | `example.com` | `terraform.tfvars` |
| `${VPS_HOST}` | 基础 IP | `1.2.3.4` | `terraform.tfvars` (for context) |
| `${DOMAIN_PREFIX}` | 环境前缀 | `x-staging` | `staging.tfvars` |

## 2. 命名模式 (Patterns)

### A. 全局/内部服务 (Global Internal)
*   **Pattern**: `x-{service}.${BASE_DOMAIN}`
*   **Example**: `x-atlantis.example.com`

### B. 环境服务 (Environment Services)
*   **Pattern**: `{service}-${DOMAIN_PREFIX}.${BASE_DOMAIN}`
*   **Example** (Staging): `{service}-x-staging.example.com`

## 3. 服务列表 (Service List)

| Category | Service | `{service}` Name | Pattern | Full Example URL | Managed By |
|----------|---------|------------------|---------|------------------|------------|
| **Global** | Atlantis | `atlantis` | **A** | `https://x-atlantis.${BASE_DOMAIN}` | L1 (Nodep) |
| **Global** | K3s API | `k3s` | **A** | `https://x-k3s.${BASE_DOMAIN}` | L1 (Nodep) |
| **Env** | Kubero UI | `api` | **B** | `https://api-${DOMAIN_PREFIX}.${BASE_DOMAIN}` | L2 (Networking) |
| **Env** | Kubero Backend | `api` | **B** | `https://api-${DOMAIN_PREFIX}.${BASE_DOMAIN}` | L2 (Networking) |
| **Env** | Infisical | `cloud` | **B** | `https://cloud-${DOMAIN_PREFIX}.${BASE_DOMAIN}` | L2 (Networking) |
| **Env** | SigNoz | `signoz` | **B** | `https://signoz-${DOMAIN_PREFIX}.${BASE_DOMAIN}` | L2 (Observability) |
| **Env** | PostHog | `posthog` | **B** | `https://posthog-${DOMAIN_PREFIX}.${BASE_DOMAIN}` | L2 (Observability) |
| **App** | Frontend | (root) | **B***| `https://${DOMAIN_PREFIX}.${BASE_DOMAIN}` | L2 (Networking) |

> *Frontend uses the prefix directly as the subdomain in the environment pattern.
