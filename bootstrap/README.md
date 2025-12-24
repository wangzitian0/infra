# bootstrap (Bootstrap Layer)

**Scope**: Zero-dependency infrastructure bootstrap and CI/CD Orchestrator.

- **K3s Cluster**: VPS provisioning via SSH
- **Digger Orchestrator**: Self-hosted CI/CD backend (OpenTaco)
- **DNS/Cert**: Cloudflare DNS + Let's Encrypt
- **Namespace**: `kube-system`, `bootstrap` (Bootstrap layer)

## Architecture

This layer runs **first** and has no dependencies on other layers. It establishes the "Trust Anchor" by deploying the **Digger Orchestrator**, which manages all subsequent layers (L2-L4).

> [!IMPORTANT]
> To avoid circular dependencies, the `bootstrap` layer is managed by a **dedicated GitHub Actions workflow** (`bootstrap-deploy.yml`), not by Digger itself.

### Network & Domain Scheme

Infrastructure uses two primary domain sets:
- **Internal/Infra**: Uses `INTERNAL_DOMAIN` (e.g., `secrets.xxx`, `digger.xxx`).
- **External/App**: Uses `BASE_DOMAIN` with `x-*` prefixes for dev/test (`x-staging.xxx`) or root for prod (`xxx`).

Full DNS patterns, proxy rules, and proxy modes are defined in the **[Bootstrap Network SSOT](../docs/ssot/bootstrap.network.md)**.

### Core Components

| File | Component | Purpose |
|------|-----------|---------|
| `1.k3s.tf` | K3s Cluster | SSH-based VPS bootstrap |
| `2.digger.tf` | Digger Orchestrator | Self-hosted backend for GitOps CI/CD |
| `3.dns_and_cert.tf` | DNS + Certs | Cloudflare + cert-manager. See **[Network SSOT](../docs/ssot/bootstrap.network.md)**. |
| `5.platform_pg.tf` | Platform PostgreSQL | Trust anchor DB for Vault, Casdoor, and Digger |

---

## CI/CD Workflow

Managed via the `/bootstrap` command in PR comments. Output is summarized for readability.
- `/bootstrap plan`: Preview changes.
- `/bootstrap apply`: Deploy changes.


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

- [tools/](./tools): Shared CI/CD scripts and formatting tools.

## Variable Passthrough

The CI loader (`tools/secrets/ci_load_secrets.py`) ensures the following are passed to Digger:

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
