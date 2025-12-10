# Network & Domain Architecture

> Aligned with [AGENTS.md](../../AGENTS.md) 4-Layer Design (L1-L4).

## 1. DNS Architecture

**Cloudflare DNS + Nginx Ingress Routing**:

| Record | Cloudflare Mode | Purpose |
|--------|-----------------|---------|
| Infra A records | Orange cloud (proxied) for HTTPS services; grey/DNS-only for `k3s` | Infra/admin endpoints (`atlantis`, `kdashboard`, `secrets`, `k3s` on :6443 direct), `kcloud`, `kapi`, `signoz`, `posthog` |
| `*` (wildcard on BASE_DOMAIN) | Orange cloud (proxied) | Public/env wildcard on `BASE_DOMAIN` (`x-*`, app subdomains) |
| `@` (root on BASE_DOMAIN) | Orange cloud (proxied) | Public landing page |
| `x-*` (on BASE_DOMAIN) | Orange cloud (proxied) | Staging/test entrypoints (e.g., `x-staging`, CI-managed `x-test*`) |
| `*` (wildcard on INTERNAL_DOMAIN) | Orange cloud (proxied) | Optional: only when `INTERNAL_DOMAIN` uses a distinct zone (overridden by explicit infra records) |

All HTTP/HTTPS (80/443) services route through Nginx Ingress Controller.

## 2. Domain Patterns

`BASE_DOMAIN` is reserved for prod/root and business envs (`truealpha.club`). `INTERNAL_DOMAIN` defaults to `BASE_DOMAIN` and serves infra-only traffic without a prefix. If `INTERNAL_DOMAIN` differs and `internal_zone_id` is empty, Terraform auto-looks up the Cloudflare zone for `INTERNAL_DOMAIN` (otherwise falls back to `CLOUDFLARE_ZONE_ID`).

| Pattern | Prefix | Cloudflare | Description |
|---------|--------|------------|-------------|
| **Infra domain** | `{service}.${INTERNAL_DOMAIN}` | Orange cloud (k3s grey) | Infrastructure/admin services (L1/L2), `k3s` stays DNS-only |
| **x-** (External) | `x-{env}-{service}.${BASE_DOMAIN}` | Orange cloud | User-facing services with CDN (L3/L4) |
| **Prod/root** | `{service}.${BASE_DOMAIN}` | Orange cloud | Production/root endpoints without prefix |

### Pattern Details

```
Infra (INTERNAL_DOMAIN, per-record proxy; k3s is grey)
├── atlantis            # Terraform CI/CD
├── secrets             # Vault (Secrets Management)
├── kdashboard          # K8s Dashboard
├── k3s                 # K3s API (port 6443, DNS-only; direct to node, no Cloudflare proxy)
├── kcloud              # Kubero UI (disabled)
├── kapi                # Kubero API (disabled)
├── signoz              # SigNoz (Observability)
├── posthog             # PostHog (Product analytics)

x-* on BASE_DOMAIN (External/Test, proxied)
├── x-staging-*             # Staging environment
│   ├── x-staging-app
│   └── x-staging-api
└── x-test*                 # Ephemeral test environments
    ├── x-testpr-{num}-{service}      # PR previews
    └── x-testcommit-{hash}-{service} # Commit previews

Production on BASE_DOMAIN (No prefix, proxied)
├── {base_domain}           # truealpha.club
├── api.{base_domain}       # api.truealpha.club
└── {service}.{base_domain}
```

## 3. Service Map by Layer

> Last verified: 2025-12-10

### L1: Bootstrap (Internal)

| Service | Domain | Curl | Status |
|---------|--------|------|--------|
| K3s API | `k3s.${INTERNAL_DOMAIN}` (connect :6443, DNS-only) | 401 Unauthorized | ✅ Active |
| Atlantis | `atlantis.${INTERNAL_DOMAIN}` | `{"status":"ok"}` | ✅ Active |
| Cert-Manager | N/A | - | ✅ Active (internal) |
| Ingress-Nginx | N/A | - | ✅ Active (internal) |

### L2: Platform (Internal)

| Service | Domain | Curl | Status |
|---------|--------|------|--------|
| Vault | `secrets.${INTERNAL_DOMAIN}` | 404/Sealed (Vault UI) | ⏸️ Pending init/unseal |
| K8s Dashboard | `kdashboard.${INTERNAL_DOMAIN}` | 200 (Dashboard UI) | ✅ Active |
| Kubero UI | `kcloud.${INTERNAL_DOMAIN}` | 200 (404 backend) | ⏸️ Not deployed |
| Kubero API | `kapi.${INTERNAL_DOMAIN}` | 200 (404 backend) | ⏸️ Not deployed |

### L3: Data (Internal)

| Service | Domain | Curl | Status |
|---------|--------|------|--------|
| PostgreSQL | N/A (ClusterIP) | - | ⏸️ Planned |
| Redis | N/A (ClusterIP) | - | ⏸️ Planned |

### L4: Insight (Internal)

| Service | Domain | Curl | Status |
|---------|--------|------|--------|
| SigNoz | `signoz.${INTERNAL_DOMAIN}` | 404 (no backend) | ⏸️ Not deployed |
| PostHog | `posthog.${INTERNAL_DOMAIN}` | 404 (no backend) | ⏸️ Not deployed |

### External Services (User-facing)

| Environment | Domain | Curl | Status |
|-------------|--------|------|--------|
| **Production** | `truealpha.club` | 526 (SSL error) | ⚠️ No ingress configured |
| **Production** | `api.truealpha.club` | 404 (no backend) | ⏸️ Not deployed |
| Staging | `x-staging-*.truealpha.club` | 404 (no backend) | ⏸️ Not deployed |
| Test (PR) | `x-testpr-{num}-*.truealpha.club` | - | ⏸️ CI-managed |
| Test (Commit) | `x-testcommit-{hash}-*.truealpha.club` | - | ⏸️ CI-managed |

**Note**: Domains without dedicated ingress currently return 404 (no default backend).

## 4. Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `${BASE_DOMAIN}` | Prod/public root domain | `truealpha.club` |
| `${INTERNAL_DOMAIN}` | Internal/infra base domain for infra hosts (defaults to `${BASE_DOMAIN}`) | `internal.org` |
| `${VPS_HOST}` | VPS IP | `203.0.113.10` |
| `{env}` | Environment | `staging`, `prod`, `test-pr-123` |
| `{service}` | Service name | `app`, `api`, `signoz` |

## 5. Cloudflare DNS Records (Terraform)

Defined in `3.dns_and_cert.tf`:

```hcl
# Infra (i-*, DNS-only / grey cloud)
cloudflare_record.infra_records: [
  i-atlantis, i-k3s, i-secrets, i-kdashboard, i-kcloud, i-kapi, i-signoz, i-posthog
] -> VPS_IP (proxied = false)

# Optional wildcard when INTERNAL_DOMAIN uses a separate zone
cloudflare_record.wildcard_internal: * -> VPS_IP (grey cloud, only if INTERNAL_DOMAIN zone differs)

# Public wildcard: proxied for apps/x-* (explicit i-* overrides)
cloudflare_record.wildcard_public: * -> VPS_IP (orange cloud)

# Root: proxied for production
cloudflare_record.root: @ -> VPS_IP (orange cloud)

# Staging: proxied with CDN protection
cloudflare_record.x_staging: x-staging -> VPS_IP (orange cloud)

# Production: uses root domain directly (api.base.com, etc.)
# No x-prod prefix - handled by wildcard or explicit records

# Ephemeral test envs: CI-managed DNS records
# x-testpr-123, x-testcommit-abc123, etc.
```
