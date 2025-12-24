# platform (Platform Layer)

> **Role**: Consolidated Control Plane (Vault, Casdoor, Portal)
> **Dependencies**: Bootstrap (K3s, Platform PG)

This layer provides the core shared services for the infrastructure, including Identity (Casdoor), Secrets (Vault), and Observability.

## 📚 SSOT References (Start Here)

For authoritative architecture, configuration rules, and SOPs, refer to the **Single Source of Truth (SSOT)**:

| Topic | SSOT Document | Key Contents |
|-------|---------------|--------------|
| **Auth** | [**Platform Auth SSOT**](../docs/ssot/platform.auth.md) | Casdoor SSO, Vault RBAC, Portal Gate |
| **Secrets** | [**Platform Secrets SSOT**](../docs/ssot/platform.secrets.md) | 1Password -> GitHub -> Vault Flow |
| **AI** | [**Platform AI SSOT**](../docs/ssot/platform.ai.md) | OpenRouter Integration |
| **Network** | [**Platform Network SSOT**](../docs/ssot/platform.network.md) | Domain mapping (Internal vs Public) |

---

## 🏗️ Core Components

| File | Component | Purpose |
|------|-----------|---------|
| `2.vault.tf` | **Vault** | Secrets engine (backed by L1 Platform PG) |
| `5.casdoor.tf` | **Casdoor** | SSO Identity Provider (IdP) |
| `3.dashboard.tf` | **Dashboard** | K8s management UI (Protected by Portal Gate) |
| `4.portal.tf` | **Homer** | Unified landing page (`home.<internal_domain>`) |
| `10.kubero.tf` | **Kubero** | PaaS for application deployment |
| `90-92.*.tf` | **Integrations** | OIDC wiring, Roles, Policies |

## 🚦 Operational Guide

### Deployment
> Managed by Digger Orchestrator (GitOps).

- **Plan**: Comment `/plan` on PR
- **Apply**: Comment `/apply` on PR

### Local Development
```bash
cd platform
# Requires kubeconfig and valid credentials in environment
terragrunt init
terragrunt plan
```

### Access Points

- **Portal**: `https://home.<internal_domain>` (Start here)
- **Vault**: `https://secrets.<internal_domain>`
- **Casdoor**: `https://sso.<internal_domain>`
- **Dashboard**: `https://kdashboard.<internal_domain>`

> Default `internal_domain` is `zitian.party`.

---

## Recent Changes

### 2025-12-24: SSOT Refactor
- Migrated detailed documentation to `docs/ssot/platform.*.md`.
- Simplified README to serve as a navigation hub.

---
*Last updated: 2025-12-25*