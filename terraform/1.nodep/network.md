# Network & Domain Architecture

> Aligned with [AGENTS.md](../../AGENTS.md) 4-Layer Design (L1-L4).

## 1. DNS Architecture

**Cloudflare DNS + Nginx Ingress Routing**:

| Record | Cloudflare Mode | Purpose |
|--------|-----------------|---------|
| `*` (wildcard) | Grey cloud (DNS-only) | Internal services, may use non-standard ports |
| `@` (root) | Orange cloud (proxied) | Public landing page |
| `x-*` | Orange cloud (proxied) | External user-facing services with CDN/DDoS protection |

All HTTP/HTTPS (80/443) services route through Nginx Ingress Controller.

## 2. Domain Patterns

| Pattern | Prefix | Cloudflare | Description |
|---------|--------|------------|-------------|
| **i-** (Internal) | `i-{service}` | Grey cloud | Infrastructure/admin services (L1/L2) |
| **x-** (External) | `x-{env}-{service}` | Orange cloud | User-facing services with CDN (L3/L4) |

### Pattern Details

```
i-* (Internal/Infrastructure)
├── i-atlantis        # Terraform CI/CD
├── i-secrets         # Infisical (Secrets Management)
├── i-kdashboard      # K8s Dashboard
├── i-k3s             # K3s API (port 6443)
├── i-kcloud          # Kubero UI (disabled)
├── i-kapi            # Kubero API (disabled)
├── i-signoz          # SigNoz (Observability)
└── i-posthog         # PostHog (Analytics)

x-* (External/Test environments, Orange Cloud)
├── x-staging-*           # Staging environment
│   ├── x-staging-app
│   └── x-staging-api
└── x-test*               # Ephemeral test environments
    ├── x-testpr-{num}-{service}      # PR previews
    └── x-testcommit-{hash}-{service} # Commit previews

Production (No prefix, direct domain)
├── {base_domain}         # truealpha.club
├── api.{base_domain}     # api.truealpha.club
└── {service}.{base_domain}
```

## 3. Service Map by Layer

### L1: Bootstrap (Internal)

| Service | Domain | Status | Notes |
|---------|--------|--------|-------|
| K3s API | `i-k3s.${BASE_DOMAIN}:6443` | ✅ Active | DNS-only, non-standard port |
| Atlantis | `i-atlantis.${BASE_DOMAIN}` | ✅ Active | Terraform CI/CD |
| Cert-Manager | N/A | ✅ Active | Internal only |
| Ingress-Nginx | N/A | ✅ Active | Internal only |

### L2: Platform (Internal)

| Service | Domain | Status | Notes |
|---------|--------|--------|-------|
| Infisical | `i-secrets.${BASE_DOMAIN}` | ✅ Active | Secrets Management |
| K8s Dashboard | `i-kdashboard.${BASE_DOMAIN}` | ✅ Active | Cluster UI |
| Kubero UI | `i-kcloud.${BASE_DOMAIN}` | ⏸️ Disabled | Chart repo unreachable |
| Kubero API | `i-kapi.${BASE_DOMAIN}` | ⏸️ Disabled | Chart repo unreachable |

### L3: Data (Internal)

| Service | Domain | Status | Notes |
|---------|--------|--------|-------|
| PostgreSQL | N/A (ClusterIP) | ⏸️ Planned | Internal only |
| Redis | N/A (ClusterIP) | ⏸️ Planned | Internal only |

### L4: Insight (Internal)

| Service | Domain | Status | Notes |
|---------|--------|--------|-------|
| SigNoz | `i-signoz.${BASE_DOMAIN}` | ⏸️ Planned | Observability |
| PostHog | `i-posthog.${BASE_DOMAIN}` | ⏸️ Planned | Analytics |

### External Services (User-facing)

| Environment | Pattern | Example | Notes |
|-------------|---------|---------|-------|
| **Production** | `{service}.${BASE_DOMAIN}` | `api.truealpha.club` | Direct domain, no prefix |
| Staging | `x-staging-{service}` | `x-staging-app`, `x-staging-api` | Stable test env |
| Test (PR) | `x-testpr-{num}-{service}` | `x-testpr-123-app` | Ephemeral, CI-managed |
| Test (Commit) | `x-testcommit-{hash}-{service}` | `x-testcommit-abc123-api` | Ephemeral, CI-managed |

## 4. Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `${BASE_DOMAIN}` | Root domain | `truealpha.club` |
| `${VPS_HOST}` | VPS IP | `103.214.23.41` |
| `{env}` | Environment | `staging`, `prod`, `test-pr-123` |
| `{service}` | Service name | `app`, `api`, `signoz` |

## 5. Cloudflare DNS Records (Terraform)

Defined in `3.dns_and_cert.tf`:

```hcl
# Wildcard: DNS-only for i-* internal services
cloudflare_record.wildcard: * → VPS_IP (grey cloud)

# Root: proxied for production
cloudflare_record.root: @ → VPS_IP (orange cloud)

# Staging: proxied with CDN protection
cloudflare_record.x_staging: x-staging → VPS_IP (orange cloud)

# Production: uses root domain directly (api.base.com, etc.)
# No x-prod prefix - handled by wildcard or explicit records

# Ephemeral test envs: CI-managed DNS records
# x-testpr-123, x-testcommit-abc123, etc.
```
