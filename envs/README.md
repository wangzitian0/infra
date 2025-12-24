# Environments (Envs)

> **Role**: Environment Configuration Layer
> **Dependencies**: Platform

This directory implements the **Environment Isolation** strategy, defining specific configurations for Staging and Production.

## 📚 SSOT References (Start Here)

For the authoritative environment model, refer to:
> [**Core SSOT / Environment Isolation**](../docs/ssot/core.md#3-环境隔离)

## Directory Structure

| Path | Environment | Purpose |
|------|-------------|---------|
| `staging/data/` | **Staging** | Validation environment for business data |
| `prod/data/` | **Production** | Live environment for business data |
| `data-shared/` | **Shared** | Templates and module definitions |

## Isolation Strategy

| Dimension | Strategy | Implementation |
|-----------|----------|----------------|
| **Cluster** | Shared | Single K3s cluster for efficiency |
| **Namespace** | Isolated | `data-staging` vs `data-prod` |
| **State** | Isolated | Separate Terraform state files in R2 |
| **Vault** | Isolated | Separate Vault Paths & Roles |

---
*Last updated: 2025-12-25*