# Network & Domain Architecture

> Aligned with [AGENTS.md](../../AGENTS.md) 4-Layer Design (L1-L4).

## 1. DNS Architecture

**Cloudflare Wildcard DNS + Ingress Routing**:
- `*` (wildcard) → VPS IP (grey cloud, DNS-only for internal `i-*` services)
- `@` (root) → VPS IP (orange cloud, proxied)
- `x-*` → VPS IP (orange cloud, external services per env)

All HTTP/HTTPS (80/443) services route through Nginx Ingress Controller.

## 2. Domain Patterns

| Pattern | Prefix | Template | Description |
|---------|--------|----------|-------------|
| **A** (Singleton) | `i-` | `i-{service}.${BASE_DOMAIN}` | L1/L2 singleton services |
| **B** (Per-Env) | `{env}-` | `{env}-{service}.${BASE_DOMAIN}` | L3/L4 environment-isolated services |

**Examples**:
- Pattern A: `i-atlantis.truealpha.club`, `i-secrets.truealpha.club`
- Pattern B: `staging-signoz.truealpha.club`, `prod-posthog.truealpha.club`

## 3. Service Map by Layer

### L1: Bootstrap (Singleton)

| Service | Domain | Notes |
|---------|--------|-------|
| K3s API | `i-k3s.${BASE_DOMAIN}` | DNS-only (port 6443) |
| Atlantis | `i-atlantis.${BASE_DOMAIN}` | Terraform CI/CD |
| Cert-Manager | N/A | Internal only |
| Ingress-Nginx | N/A | Internal only |

### L2: Platform (Singleton)

| Service | Domain | Notes |
|---------|--------|-------|
| Infisical | `i-secrets.${BASE_DOMAIN}` | Secrets Management |
| K8s Dashboard | `i-kdashboard.${BASE_DOMAIN}` | Cluster UI |
| Kubero UI | `i-kcloud.${BASE_DOMAIN}` | PaaS (disabled - chart repo unreachable) |
| Kubero API | `i-kapi.${BASE_DOMAIN}` | PaaS API (disabled) |

### L3: Data (Per-Env)

| Service | Domain | Environments |
|---------|--------|--------------|
| PostgreSQL | N/A (Internal) | staging, prod |
| Redis | N/A (Internal) | staging, prod |

### L4: Insight (Per-Env)

| Service | Domain | Environments |
|---------|--------|--------------|
| SigNoz | `{env}-signoz.${BASE_DOMAIN}` | staging, prod |
| PostHog | `{env}-posthog.${BASE_DOMAIN}` | staging, prod |

## 4. Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `${BASE_DOMAIN}` | Root domain | `truealpha.club` |
| `${VPS_HOST}` | VPS IP | `103.214.23.41` |
| `{env}` | Environment prefix | `staging`, `prod` |
