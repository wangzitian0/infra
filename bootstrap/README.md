# bootstrap (Bootstrap Layer)

> **Role**: Trust Anchor & CI/CD Orchestrator
> **Dependencies**: Zero (Start here)

The `bootstrap` layer establishes the foundation of the entire infrastructure. It provisions the Kubernetes cluster and the GitOps orchestrator (Digger) that manages all subsequent layers (L2-L4).

## 📚 SSOT References (Start Here)

For authoritative architecture, configuration rules, and SOPs, refer to the **Single Source of Truth (SSOT)**:

| Topic | SSOT Document | Key Contents |
|-------|---------------|--------------|
| **Compute** | [**Bootstrap Compute SSOT**](../docs/ssot/bootstrap.compute.md) | K3s Cluster, Digger Orchestrator, L1 CI Flow |
| **Storage** | [**Bootstrap Storage SSOT**](../docs/ssot/bootstrap.storage.md) | StorageClass, Platform PG (Trust Anchor) |
| **Network** | [**Bootstrap Network SSOT**](../docs/ssot/bootstrap.network.md) | Cloudflare DNS Mode, TLS Certs, Ingress |

---

## 🚦 Operational Guide

### CI/CD Workflow
> See [**Compute SSOT / Playbooks**](../docs/ssot/bootstrap.compute.md#sop-002-部署更新-l1-bootstrap) for detailed SOP.

- **Trigger**: GitHub Actions workflow `bootstrap-deploy.yml`
- **Commands**:
    - Comment `/bootstrap plan` on PR
    - Comment `/bootstrap apply` on PR
    - Push to `main` (Auto Apply)

Push to `main` will trigger an automatic drift scan/apply for the Bootstrap layer (post-merge reconciliation).

### Local Deployment (Emergency)
> See [**Compute SSOT / Constraints**](../docs/ssot/bootstrap.compute.md#设计约束-dos--donts) for when this is allowed.

**Bootstrap Command (Manual/Local)**

```bash
cd bootstrap
terraform init -backend-config=backend.tfvars
terraform apply
```

---

## 🏗️ Core Components

| File | Component | SSOT Reference |
|------|-----------|----------------|
| `1.k3s.tf` | K3s Cluster | [Compute SSOT](../docs/ssot/bootstrap.compute.md) |
| `2.digger.tf` | Digger Orchestrator | [Compute SSOT](../docs/ssot/bootstrap.compute.md) |
| `3.dns_and_cert.tf` | DNS + Certs | [Network SSOT](../docs/ssot/bootstrap.network.md) |
| `4.storage.tf` | StorageClass | [Storage SSOT](../docs/ssot/bootstrap.storage.md) |
| `5.platform_pg.tf` | Platform PG | [Storage SSOT](../docs/ssot/bootstrap.storage.md) |

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

---

## Recent Changes

### 2025-12-24: Digger Orchestrator Migration
- **Component**: Replaced Atlantis with self-hosted Digger Orchestrator (OpenTaco).
- **Architecture**: Separated Bootstrap CI from Digger via `bootstrap-deploy.yml`.
- **Database**: Added `digger` database to Platform PostgreSQL (CNPG).

### 2025-12-25: Digger HTTPS Guard Fix
- **Guardrail**: Fixed HTTPS postcondition check for Digger ingress to avoid false plan failures.

### 2025-12-25: Bootstrap Health Checks Moved to CI
- **E2E**: DNS/HTTPS checks for Digger moved out of Terraform and into post-apply CI.

### 2025-12-25: Bootstrap Drift Adopt (Existing Resources)
- **Import**: CI auto-imports existing Helm releases and secrets before apply.

---
*Last updated: 2025-12-25*
