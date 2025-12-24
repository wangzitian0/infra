# data-shared (Data Layer)

> **Role**: Shared Database Infrastructure (L3)
> **Dependencies**: Platform (Vault)

This layer provides shared data services for all environments, including PostgreSQL, Redis, ClickHouse, and ArangoDB.

## 📚 SSOT References (Start Here)

For authoritative architecture, configuration rules, and SOPs, refer to the **Single Source of Truth (SSOT)**:

| Topic | SSOT Document | Key Contents |
|-------|---------------|--------------|
| **Overview** | [**Database Overview SSOT**](../../docs/ssot/db.overview.md) | Capability map, Vault Agent model |
| **Vault** | [**Vault Integration SSOT**](../../docs/ssot/db.vault-integration.md) | How to connect your app |
| **PostgreSQL** | [**Business PG SSOT**](../../docs/ssot/db.business_pg.md) | L3 Business Database specs |
| **Redis** | [**Redis SSOT**](../../docs/ssot/db.redis.md) | Global cache configuration |

---

## 🏗️ Core Components

| File | Component | Purpose |
|------|-----------|---------|
| `1.postgres.tf` | **Business PG** | Multi-tenant PostgreSQL cluster |
| `2.redis.tf` | **Redis** | Caching and messaging |
| `3.clickhouse.tf` | **ClickHouse** | OLAP and observability backend |

---

## 🚦 Operational Guide

### Deployment
> Managed by Digger Orchestrator (GitOps).

- **Plan**: Comment `/plan` on PR
- **Apply**: Comment `/apply` on PR

---
*Last updated: 2025-12-25*
