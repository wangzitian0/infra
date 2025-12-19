# 数据库总览 SSOT

> **核心问题**：哪些 DB 属于哪个层？密码谁管？应用如何接入？

## Vault 接入机制（Per-App Token）

每个应用通过 **Kubernetes ServiceAccount** 获取独立的 Vault Token，实现最小权限和审计隔离：

```mermaid
graph LR
    SA[App ServiceAccount] -->|K8s JWT| VKA[Vault K8s Auth]
    VKA -->|验证 SA| ROLE[Vault Role]
    ROLE -->|绑定| POLICY[Vault Policy]
    POLICY -->|授权| SECRET[DB Secrets]
    SECRET -->|Agent 注入| POD[App Pod]
```

**详细接入流程** → [db.vault-integration.md](./db.vault-integration.md)

---

## 服务矩阵

| 数据库 | 层级 | 命名空间 | 密码来源 | 消费者 | 详情 |
|--------|------|----------|----------|--------|------|
| **Platform PG** | L1 | `platform` | GitHub Secret | Vault, Casdoor | [db.platform_pg.md](./db.platform_pg.md) |
| **Business PG** | L3 | `data-<env>` | Vault | L4 Apps | [db.business_pg.md](./db.business_pg.md) |
| **Redis** | L3 | `data-<env>` | Vault | L4 Apps (Cache) | [db.redis.md](./db.redis.md) |
| **ClickHouse** | L3 | `data-<env>` | Vault | L4 Apps, SigNoz | [db.clickhouse.md](./db.clickhouse.md) |
| **ArangoDB** | L3 | `data-<env>` | Vault | L4 Apps (Graph) | [db.arangodb.md](./db.arangodb.md) |

---

## Quick Start

### PostgreSQL

| 属性 | 值 |
|------|------|
| **服务地址** | `postgresql.data-<env>.svc.cluster.local:5432` |
| **Vault 静态密码** | `secret/data/data/postgres` |
| **Vault 动态凭据** | `database/creds/app-readonly` / `app-readwrite` |

```yaml
# Pod annotations (使用 Vault Agent Injector)
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "my-app"
  vault.hashicorp.com/agent-inject-secret-pg: "secret/data/data/postgres"
  vault.hashicorp.com/agent-inject-template-pg: |
    {{- with secret "secret/data/data/postgres" -}}
    export PGPASSWORD="{{ .Data.data.password }}"
    {{- end }}
```

---

### Redis

| 属性 | 值 |
|------|------|
| **服务地址** | `redis-master.data-<env>.svc.cluster.local:6379` |
| **Vault 路径** | `secret/data/data/redis` |

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "my-app"
  vault.hashicorp.com/agent-inject-secret-redis: "secret/data/data/redis"
  vault.hashicorp.com/agent-inject-template-redis: |
    {{- with secret "secret/data/data/redis" -}}
    export REDIS_PASSWORD="{{ .Data.data.password }}"
    {{- end }}
```

---

### ClickHouse

| 属性 | 值 |
|------|------|
| **服务地址** | `clickhouse.data-<env>.svc.cluster.local` |
| **端口** | 8123 (HTTP) / 9000 (Native) |
| **Vault 路径** | `secret/data/data/clickhouse` |

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "my-app"
  vault.hashicorp.com/agent-inject-secret-ch: "secret/data/data/clickhouse"
  vault.hashicorp.com/agent-inject-template-ch: |
    {{- with secret "secret/data/data/clickhouse" -}}
    export CLICKHOUSE_PASSWORD="{{ .Data.data.password }}"
    {{- end }}
```

---

### ArangoDB

| 属性 | 值 |
|------|------|
| **服务地址** | `arangodb.data-<env>.svc.cluster.local:8529` |
| **Vault 路径** | `secret/data/data/arangodb` |
| **字段** | `password` (root), `jwt_secret` |

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "my-app"
  vault.hashicorp.com/agent-inject-secret-arango: "secret/data/data/arangodb"
  vault.hashicorp.com/agent-inject-template-arango: |
    {{- with secret "secret/data/data/arangodb" -}}
    export ARANGO_PASSWORD="{{ .Data.data.password }}"
    {{- end }}
```

---

## 架构图

```
┌─────────────────────────────────────────────────────────────┐
│  L1 Bootstrap — Platform PostgreSQL                         │
│  密码: GitHub Secret (打破 SSOT)                             │
└─────────────────────────────────────────────────────────────┘
                           ↓ 依赖
┌─────────────────────────────────────────────────────────────┐
│  L2 Platform — Vault                                        │
│  生成 L3 密码 → 存入 Vault KV                                 │
│  配置 K8s Auth → 每个 App 独立 Role/Policy                   │
└─────────────────────────────────────────────────────────────┘
                           ↓ 供给
┌─────────────────────────────────────────────────────────────┐
│  L3 Data — 业务数据库 (data-staging / data-prod)             │
│  PostgreSQL | Redis | ClickHouse | ArangoDB                 │
│  密码: 从 Vault KV 读取部署                                  │
└─────────────────────────────────────────────────────────────┘
                           ↓ 消费
┌─────────────────────────────────────────────────────────────┐
│  L4 Apps — 应用层                                           │
│  通过 Vault Agent Injector 获取 DB 凭据                      │
└─────────────────────────────────────────────────────────────┘
```

---

> 变更记录见 [change_log/](../change_log/README.md)
