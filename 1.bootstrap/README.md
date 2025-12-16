# 1.bootstrap (L1 Bootstrap Layer)

**Scope**: Zero-dependency infrastructure bootstrap.

- **K3s Cluster**: VPS provisioning via SSH
- **Atlantis CI**: GitOps workflow engine
- **DNS/Cert**: Cloudflare DNS + Let's Encrypt
- **Namespace**: `kube-system`, `bootstrap` (L1 layer)

## Architecture

This layer runs **first** and has no dependencies on other layers.
Managed by **GitHub Actions only** (not Atlantis).

### Components

| File | Component | Purpose |
|------|-----------|---------|
| `1.k3s.tf` | K3s Cluster | SSH-based VPS bootstrap |
| `2.atlantis.tf` | Atlantis | GitOps CI/CD for L2-L4 |
| `3.dns_and_cert.tf` | DNS + Certs | Cloudflare + cert-manager |
| `5.platform_pg.tf` | Platform PostgreSQL | Trust anchor DB for Vault/Casdoor (uses `initdb.scripts` for automatic database creation) |

## Key Files

| File | Purpose |
|------|---------|
| `backend.tf` | R2/S3 state backend config |
| `providers.tf` | Provider definitions |
| `variables.tf` | All L1 variables |
| `outputs.tf` | Kubeconfig + R2 credentials for L2 |

## Domain Scheme

- Infra uses the dedicated `INTERNAL_DOMAIN` without prefixes (e.g., `secrets.internal.org`, `atlantis.internal.org`); `k3s` stays DNS-only on :6443 (no Cloudflare proxy).
- Env/test uses `x-*` on `BASE_DOMAIN` (proxied/orange): `x-staging`, `x-staging-api`, CI-managed `x-test*`.
- Prod keeps root/no-prefix on `BASE_DOMAIN` (proxied/orange): `truealpha.club`, `api.truealpha.club`.
- DNS inputs: `CLOUDFLARE_ZONE_ID` for `BASE_DOMAIN`; `INTERNAL_ZONE_ID` optionally overrides infra zone (falls back to `CLOUDFLARE_ZONE_ID`). Infra records are explicit A records with per-host proxy (443 services proxied, `k3s` DNS-only).
- Certificates: wildcard for `BASE_DOMAIN`; wildcard for `INTERNAL_DOMAIN` when distinct (separate secret). Ingresses also request per-host certs via cert-manager ingress shim.

SSOT:
- [docs/ssot/env.md](../docs/ssot/env.md) (environment semantics)
- [docs/ssot/network.md](../docs/ssot/network.md) (domain rules and service mapping)
- [docs/ssot/storage.md](../docs/ssot/storage.md) (StorageClass and data retention)

## Bootstrap Command

```bash
# First-time setup (run locally with credentials)
cd 1.bootstrap
terraform init
terraform apply
```

## Outputs for L2

| Output | Description |
|--------|-------------|
| `kubeconfig` | Cluster access (sensitive) |
| `r2_bucket` | State bucket name |
| `r2_account_id` | R2 endpoint |

## Atlantis TF_VAR Passthrough

L1 Atlantis passes the following variables to L2/L3:

| TF_VAR | Purpose | Source |
|--------|---------|--------|
| `vault_root_token` | Vault access for L2 database engine config | 1Password → GitHub Secret |
| `casdoor_admin_password` | Casdoor SSO admin | 1Password → GitHub Secret |
| `github_oauth_client_id` | OAuth2-Proxy | GitHub OAuth App |
| `github_oauth_client_secret` | OAuth2-Proxy | GitHub OAuth App |

## Chart Repository Migration

- **PostgreSQL Chart**: Migrated to OCI format (`oci://registry-1.docker.io/bitnamicharts`) as of 2025-12-11
- **Reason**: Bitnami deprecated HTTP chart repository in favor of OCI registry
- **Image Pin**: Use the chart default image tag (pinned via chart version). Do **NOT** override to `latest` (breaks reproducibility).

---
*Last updated: 2025-12-16*
