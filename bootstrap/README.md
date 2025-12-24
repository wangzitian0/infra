# bootstrap (Bootstrap Layer)

**Scope**: Zero-dependency infrastructure bootstrap and CI/CD Orchestrator.

- **K3s Cluster**: VPS provisioning via SSH
- **Digger Orchestrator**: Self-hosted CI/CD backend (OpenTaco)
- **DNS/Cert**: Cloudflare DNS + Let's Encrypt
- **Namespace**: `kube-system`, `bootstrap` (Bootstrap layer)

## Architecture

This layer runs **first** and has no dependencies on other layers.
It deploys the **Digger Orchestrator**, which is then used to manage all subsequent layers (L2-L4).

> [!IMPORTANT]
> To avoid circular dependencies, the `bootstrap` layer is managed by a **dedicated GitHub Actions workflow** (`bootstrap-deploy.yml`) using native Terraform, **not** by Digger itself.

### Components

| File | Component | Purpose |
|------|-----------|---------|
| `1.k3s.tf` | K3s Cluster | SSH-based VPS bootstrap |
| `2.digger.tf` | Digger Orchestrator | Self-hosted backend for GitOps CI/CD |
| `3.dns_and_cert.tf` | DNS + Certs | Cloudflare + cert-manager |
| `5.platform_pg.tf` | Platform PostgreSQL | Trust anchor DB for Vault, Casdoor, and Digger |

## Key Files

| File | Purpose |
|------|---------|
| `backend.tf` | R2/S3 state backend config |
| `providers.tf` | Provider definitions |
| `variables.tf` | All Bootstrap variables |
| `outputs.tf` | Kubeconfig + R2 credentials for Platform layer |

## Domain Scheme

- Infra uses the dedicated `INTERNAL_DOMAIN` without prefixes (e.g., `secrets.internal.org`, `digger.internal.org`); `k3s` stays DNS-only on :6443 (no Cloudflare proxy).
- Env/test uses `x-*` on `BASE_DOMAIN` (proxied/orange): `x-staging`, `x-staging-api`, CI-managed `x-test*`.
- Prod keeps root/no-prefix on `BASE_DOMAIN` (proxied/orange): `truealpha.club`, `api.truealpha.club`.
- DNS inputs: `CLOUDFLARE_ZONE_ID` for `BASE_DOMAIN`; `INTERNAL_ZONE_ID` optionally overrides infra zone (falls back to `CLOUDFLARE_ZONE_ID`).
- Certificates: Wildcard for `BASE_DOMAIN`; wildcard for `INTERNAL_DOMAIN` when distinct. Ingresses also request per-host certs via cert-manager ingress shim.

SSOT:
- [core.env.md](../docs/ssot/core.env.md) - IP/Domain assignments
- [bootstrap.compute.md](../docs/ssot/bootstrap.compute.md) - K3s & Digger architecture
- [secrets.md](../docs/ssot/secrets.md) - 1Password secret map

## CI/CD Workflow

The Bootstrap layer uses a dedicated workflow triggered by PR comments:

| Command | Action |
|---------|--------|
| `/bootstrap plan` | Preview changes to the bootstrap layer |
| `/bootstrap apply` | Deploy changes to the bootstrap layer |

Push to `main` for changes in `bootstrap/**` will also trigger an automatic plan/apply.

## Bootstrap Command (Manual/Local)

```bash
# First-time setup (run locally with credentials)
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
# Load other variables from 1Password or use -var-file
cd bootstrap
terraform init -backend-config=backend.tfvars
terraform apply
```

## Outputs for Platform layer

| Output | Description |
|--------|-------------|
| `kubeconfig` | Cluster access (sensitive) |
| `r2_bucket` | State bucket name |
| `r2_account_id` | R2 endpoint |

## Variable Passthrough

The CI loader (`0.tools/ci_load_secrets.py`) ensures the following are passed to Digger:

| TF_VAR | Source |
|--------|--------|
| `digger_bearer_token` | 1Password (Infra-Digger) |
| `vault_root_token` | 1Password (Infra-Vault) |
| `github_oauth_*` | 1Password (Infra-OAuth) |

## Chart Repository Migration

- **PostgreSQL Chart**: Migrated to OCI format (`oci://registry-1.docker.io/bitnamicharts`)
- **Reason**: Bitnami deprecated HTTP chart repository in favor of OCI registry

## Recent Changes

### 2025-12-24: Digger Orchestrator Migration
- **Component**: Replaced Atlantis with self-hosted Digger Orchestrator (OpenTaco).
- **Architecture**: Separated Bootstrap CI from Digger via `bootstrap-deploy.yml`.
- **Database**: Added `digger` database to Platform PostgreSQL (CNPG).

---
*Last updated: 2025-12-25*
