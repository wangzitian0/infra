# data (Data Layer) - Production Environment

> **环境**: Production
> **定位**: 业务数据库基础设施

**Scope**:
- **Namespace**: `data-prod`
- **Components**: PostgreSQL, Redis, ClickHouse, ArangoDB

## 📚 SSOT References (Start Here)

For authoritative architecture and SOPs, refer to the **Single Source of Truth (SSOT)**:

| Topic | SSOT Document | Key Contents |
|-------|---------------|--------------|
| **Overview** | [**Database Overview SSOT**](../../../docs/ssot/db.overview.md) | VSO Pattern, Vault Injection |
| **PostgreSQL** | [**Business PG SSOT**](../../../docs/ssot/db.business_pg.md) | Backup/Restore SOPs |
| **Redis** | [**Redis SSOT**](../../../docs/ssot/db.redis.md) | Cache policy |
| **Standards** | [**Ops Standards SSOT**](../../../docs/ssot/ops.standards.md) | Naming & Quotas |

---

## 🚦 Operational Guide

### Deployment
> Managed by Digger Orchestrator (GitOps).

- **Plan**: Comment `/plan` on PR
- **Apply**: Comment `/apply` on PR

### Access
- **Service Domain**: `*.data-prod.svc.cluster.local`
- **Credentials**: Read from Vault `secret/data/*` or use dynamic creds

---
*Last updated: 2025-12-25*