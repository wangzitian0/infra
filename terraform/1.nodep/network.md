# Network & Domain Architecture

> Aligned with [terraform/envs/README.md](../envs/README.md) 5-Layer Design.

## 1. DNS Architecture

**Cloudflare Wildcard DNS + Ingress Routing**:
- `*.truealpha.club` → VPS IP (proxied, orange cloud)
- `@` (root) → VPS IP (proxied)
- `i-k3s` → VPS IP (DNS-only, grey cloud, for port 6443)

All HTTP/HTTPS (80/443) services route through Nginx Ingress Controller.

## 2. Domain Patterns

| Pattern | Prefix | Template | Description |
|---------|--------|----------|-------------|
| **A** (Global) | `i-` | `i-{service}.${BASE_DOMAIN}` | Singleton/Shared services (L1/L2) |
| **B** (Env) | `{env}-` | `{env}-{service}.${BASE_DOMAIN}` | Environment-isolated services (L3+) |

**Examples**:
- Pattern A: `i-atlantis.truealpha.club`, `i-secrets.truealpha.club`
- Pattern B: `staging-app.truealpha.club`, `prod-signoz.truealpha.club`

## 3. Service Map by Layer

### L1: Bootstrap (Singleton)

| Service | Domain | Notes |
|---------|--------|-------|
| K3s API | `i-k3s.${BASE_DOMAIN}` | DNS-only (port 6443) |

### L2: Networking (Singleton)

| Service | Domain | Notes |
|---------|--------|-------|
| Atlantis | `i-atlantis.${BASE_DOMAIN}` | Terraform CI/CD |
| Infisical | `i-secrets.${BASE_DOMAIN}` | Secrets Management |
| Cert-Manager | N/A | Internal only |
| Ingress-Nginx | N/A | Internal only |

### L3: Platform (Per-Env)

| Service | Domain | Environments |
|---------|--------|--------------|
| Kubero UI | `{env}-kcloud.${BASE_DOMAIN}` | staging, prod |
| Kubero API | `{env}-kapi.${BASE_DOMAIN}` | staging, prod |

### L4: Data (Per-Env)

| Service | Domain | Environments |
|---------|--------|--------------|
| PostgreSQL | N/A (Internal) | staging, prod, temp-* |
| Redis | N/A (Internal) | staging, prod, temp-* |

### L5: Insight (Per-Env)

| Service | Domain | Environments |
|---------|--------|--------------|
| SigNoz | `{env}-signoz.${BASE_DOMAIN}` | staging, prod |
| PostHog | `{env}-posthog.${BASE_DOMAIN}` | staging, prod |
| App Frontend | `{env}.${BASE_DOMAIN}` | staging, prod |
| App Backend | `{env}-api.${BASE_DOMAIN}` | staging, prod |

## 4. Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `${BASE_DOMAIN}` | Root domain | `truealpha.club` |
| `${VPS_HOST}` | VPS IP | `1.2.3.4` |
| `{env}` | Environment prefix | `staging`, `prod`, `temp-xyz` |
