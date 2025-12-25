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

### Foundation Layer (01-04)
| File | Component | Purpose |
|------|-----------|---------|
| `01.vault.tf` | **Vault** | Secrets engine (backed by L1 Platform PG) |
| `02.casdoor.tf` | **Casdoor** | SSO Identity Provider (IdP) |
| `03.vault-database.tf` | **Vault DB** | Vault database backend configuration |
| `04.vault-secrets-operator.tf` | **VSO** | Vault Secrets Operator for K8s secret sync |

### User Services (20-23)
| File | Component | Purpose |
|------|-----------|---------|
| `20.kubernetes-dashboard.tf` | **Dashboard** | K8s management UI (Protected by Portal Gate) |
| `21.portal.tf` | **Homer** | Unified landing page (`home.<internal_domain>`) |
| `22.kubero.tf` | **Kubero** | PaaS for application deployment |
| `23.signoz.tf` | **SigNoz** | Observability and monitoring |

### Integration Layer (80-82)
| File | Component | Purpose |
|------|-----------|---------|
| `80.casdoor-apps.tf` | **OIDC Apps** | Casdoor application registrations |
| `81.casdoor-roles.tf` | **RBAC Roles** | Casdoor role definitions |
| `82.provider-restapi.tf` | **REST API Provider** | Casdoor REST API configuration |

### Cross-Service Configuration (90-94)
| File | Component | Purpose |
|------|-----------|---------|
| `90.vault-auth-kubernetes.tf` | **Vault K8s Auth** | Kubernetes authentication backend |
| `91.vault-oidc.tf` | **Vault OIDC** | Vault OIDC integration with Casdoor |
| `92.vault-policy-default.tf` | **Vault Policies** | Default Vault access policies |
| `93.portal-auth.tf` | **Portal Auth** | Portal authentication with Casdoor |
| `94.vault-kubero.tf` | **Kubero Secrets** | Kubero secrets in Vault |

### Health Checks (99)
| File | Component | Purpose |
|------|-----------|---------|
| `99.checks.tf` | **Health Checks** | Post-deployment verification |

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

### 2025-12-26: File Reorganization
- Reorganized Terraform files with semantic numbering for better logical grouping
- Foundation (01-04), Services (20-23), Integration (80-82), Configuration (90-94), Checks (99)
- No Terraform state changes - files renamed via `git mv`

### 2025-12-24: SSOT Refactor
- Migrated detailed documentation to `docs/ssot/platform.*.md`.
- Simplified README to serve as a navigation hub.

---
*Last updated: 2025-12-26*