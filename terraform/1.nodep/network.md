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

x-* (External/User-facing)
├── x-staging-*       # Staging environment
│   ├── x-staging-app
│   └── x-staging-api
├── x-prod-*          # Production environment
│   ├── x-prod-app
│   └── x-prod-api
└── x-test-*          # Ephemeral test environments
    ├── x-test-pr-{num}-{service}
    ├── x-test-commit-{hash}-{service}
    └── x-test-{id}-{service}
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
| Staging | `x-staging-{service}` | `x-staging-app`, `x-staging-api` | Stable test env |
| Production | `x-prod-{service}` | `x-prod-app`, `x-prod-api` | Live production |
| Test (PR) | `x-test-pr-{num}-{service}` | `x-test-pr-123-app` | Ephemeral, auto-cleanup |
| Test (Commit) | `x-test-commit-{hash}-{service}` | `x-test-commit-abc123-api` | Ephemeral, auto-cleanup |

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

# Root: proxied for public landing
cloudflare_record.root: @ → VPS_IP (orange cloud)

# External envs: proxied with CDN protection
cloudflare_record.x_staging: x-staging → VPS_IP (orange cloud)
cloudflare_record.x_prod: x-prod → VPS_IP (orange cloud)
# x-test-* records created dynamically by CI/CD
```
