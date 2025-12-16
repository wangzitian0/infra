# 数据库总览 SSOT

> **核心问题**：哪些 DB 属于哪个层？密码谁管？

## 服务矩阵

| 数据库 | 层级 | 命名空间 | 密码来源 | 消费者 | 详情 |
|--------|------|----------|----------|--------|------|
| **Platform PG** | L1 | `platform` | GitHub Secret | Vault, Casdoor | [db.platform_pg.md](./db.platform_pg.md) |
| **Business PG** | L3 | `data-<env>` | Vault | L4 Apps | [db.business_pg.md](./db.business_pg.md) |
| **Redis** | L3 | `data-<env>` | Vault | L4 Apps (Cache) | [db.redis.md](./db.redis.md) |
| **ClickHouse** | L3 | `data-<env>` | Vault | L4 Apps, SigNoz | [db.clickhouse.md](./db.clickhouse.md) |
| **ArangoDB** | L3 | `data-<env>` | Vault | L4 Apps (Graph) | [db.arangodb.md](./db.arangodb.md) |

## 架构图

```
┌─────────────────────────────────────────────────────────────┐
│  L1 Bootstrap — Platform PostgreSQL                         │
│  密码: GitHub Secret (打破 SSOT)                             │
└─────────────────────────────────────────────────────────────┘
                           ↓ 依赖
┌─────────────────────────────────────────────────────────────┐
│  L3 Data — 业务数据库 (data-staging / data-prod)             │
│  PostgreSQL | Redis | ClickHouse | ArangoDB                 │
│  密码: Vault → Vault Agent 注入                              │
└─────────────────────────────────────────────────────────────┘
```

---

