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

| 数据库 | SSOT Key | 层级 | 命名空间 | 密码来源 | 消费者 | 详情 |
|--------|----------|------|----------|----------|--------|------|
| **Platform PG** | `db.platform_pg` | Bootstrap | `platform` | GitHub Secret | Vault, Casdoor | [db.platform_pg.md](./db.platform_pg.md) |
| **Business PG** | `db.business_pg` | Data | `data-<env>` | Vault | Apps | [db.business_pg.md](./db.business_pg.md) |
| **Redis** | `db.redis` | Data | `data-<env>` | Vault | Apps (Cache) | [db.redis.md](./db.redis.md) |
| **ClickHouse** | `db.clickhouse` | Data | `data-<env>` | Vault | Apps, SigNoz | [db.clickhouse.md](./db.clickhouse.md) |
| **ArangoDB** | `db.arangodb` | Data | `data-<env>` | Vault | Apps (Graph) | [db.arangodb.md](./db.arangodb.md) |

---

## Quick Start

### PostgreSQL

| 属性 | 值 |
|------|------|
| **服务地址** | `postgresql.data-<env>.svc.cluster.local:5432` |
| **Vault 静态密码** | `secret/data/postgres` |
| **Vault 动态凭据** | `database/creds/app-readonly` / `app-readwrite` |

```yaml
# Pod annotations (使用 Vault Agent Injector)
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "my-app"
  vault.hashicorp.com/agent-inject-secret-pg: "secret/data/postgres"
  vault.hashicorp.com/agent-inject-template-pg: |
    {{- with secret "secret/data/postgres" -}}
    export PGPASSWORD="{{ .Data.data.password }}"
    {{- end }}
```

---

### Redis

| 属性 | 值 |
|------|------|
| **服务地址** | `redis-master.data-<env>.svc.cluster.local:6379` |
| **Vault 路径** | `secret/data/redis` |

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "my-app"
  vault.hashicorp.com/agent-inject-secret-redis: "secret/data/redis"
  vault.hashicorp.com/agent-inject-template-redis: |
    {{- with secret "secret/data/redis" -}}
    export REDIS_PASSWORD="{{ .Data.data.password }}"
    {{- end }}
```

---

### ClickHouse

| 属性 | 值 |
|------|------|
| **服务地址** | `clickhouse.data-<env>.svc.cluster.local` |
| **端口** | 8123 (HTTP) / 9000 (Native) |
| **Vault 路径** | `secret/data/clickhouse` |

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "my-app"
  vault.hashicorp.com/agent-inject-secret-ch: "secret/data/clickhouse"
  vault.hashicorp.com/agent-inject-template-ch: |
    {{- with secret "secret/data/clickhouse" -}}
    export CLICKHOUSE_PASSWORD="{{ .Data.data.password }}"
    {{- end }}
```

---

### ArangoDB

| 属性 | 值 |
|------|------|
| **服务地址** | `arangodb.data-<env>.svc.cluster.local:8529` |
| **Vault 路径** | `secret/data/arangodb` |
| **字段** | `password` (root), `jwt_secret` |

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "my-app"
  vault.hashicorp.com/agent-inject-secret-arango: "secret/data/arangodb"
  vault.hashicorp.com/agent-inject-template-arango: |
    {{- with secret "secret/data/arangodb" -}}
    export ARANGO_PASSWORD="{{ .Data.data.password }}"
    {{- end }}
```

---

## 架构图

```mermaid
flowchart TB
    B["Bootstrap — Platform PostgreSQL<br/>密码: GitHub Secret"]
    P["Platform — Vault<br/>生成 Data 密码 → 存入 Vault KV<br/>配置 K8s Auth → 每个 App 独立 Role/Policy"]
    D["Data — 业务数据库 (data-staging / data-prod)<br/>PostgreSQL | Redis | ClickHouse | ArangoDB<br/>密码: 从 Vault KV 读取部署"]
    A["Apps — 应用层<br/>通过 Vault Agent Injector 获取 DB 凭据"]

    B -->|依赖| P
    P -->|供给| D
    D -->|消费| A
```

---

> 变更记录见 [change_log/](../change_log/README.md)

## Used by

- [docs/ssot/db.business_pg.md](./db.business_pg.md)
- [docs/project/BRN-008.md](../project/BRN-008.md)

---

