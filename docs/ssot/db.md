# 数据库能力 SSOT

> **核心问题**：哪些 DB 属于哪个层？密码谁管？

## 架构概览

```
┌─────────────────────────────────────────────────────────────┐
│  L1 Bootstrap — Platform PostgreSQL                         │
├─────────────────────────────────────────────────────────────┤
│  用途：Vault + Casdoor 的 Backend                           │
│  StorageClass: local-path-retain                            │
│  密码来源：GitHub Secret (打破 SSOT)                         │
│  备份策略：VPS /data pg_dump + rsync                         │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│  L3 Data — 业务数据库                                        │
├─────────────────────────────────────────────────────────────┤
│  PostgreSQL (业务)  Redis    Neo4j    ClickHouse            │
│  └─ 密码: Vault     └─ Vault └─ Vault └─ Vault              │
│  └─ NS: data-<env>   └─ data-<env>  └─ data-<env>  └─ data-<env> │
│  └─ Storage: local-path-retain (持久化)                     │
└─────────────────────────────────────────────────────────────┘
```

## 服务矩阵

| 数据库 | 层级 | 命名空间 | 密码来源 | StorageClass | 消费者 |
|--------|------|----------|----------|--------------|--------|
| **Platform PG** | L1 | `platform` | GitHub Secret | `local-path-retain` | Vault, Casdoor |
| **Business PG** | L3 | `data-<env>` | Vault | `local-path-retain` | L4 Apps |
| **Redis** | L3 | `data-<env>` | Vault | `local-path-retain` | L4 Apps (Cache) |
| **Neo4j** | L3 | `data-<env>` | Vault | `local-path-retain` | L4 Apps (Graph) |
| **ClickHouse** | L3 | `data-<env>` | Vault | `local-path-retain` | L4 Apps (OLAP) |

## 为什么 Platform PG 在 L1？

1. **循环依赖**：Vault 需要 PG → 其他服务需要 Vault → 无法用 Vault 管理 Vault 的 PG 密码
2. **Trust Anchor**：L1 是信任锚点，允许打破 SSOT 规则
3. **隔离**：Platform PG 只服务于平台组件，不混用业务数据
4. **备份**：`pg_dump` 比 Raft snapshot 更标准，易于恢复

## 连接方式

| 消费者 | 目标 DB | 连接字符串来源 | 凭证类型 |
|--------|---------|----------------|----------|
| Vault Pod | Platform PG | Helm values (L1 注入) | 静态 (GitHub Secret) |
| Casdoor Pod | Platform PG | Helm values (L1 注入) | 静态 (GitHub Secret) |
| L4 App Pod | Business PG | Vault Agent 注入 | **动态** (Vault Database Engine) |
| L4 App Pod | Redis | Vault Agent 注入 | 静态 (Vault KV) |
| L4 App Pod | ClickHouse | Vault Agent 注入 | 静态 (Vault KV) |
| L4 App Pod | ArangoDB | Vault Agent 注入 | 静态 (Vault KV) |

---

### Kubernetes 服务发现

所有 L3 数据库通过 K8s Service 暴露：

| 数据库 | 服务地址 | 端口 |
|--------|----------|------|
| PostgreSQL | `postgresql.data-default.svc.cluster.local` | 5432 |
| Redis | `redis-master.data-default.svc.cluster.local` | 6379 |
| ClickHouse | `clickhouse.data-default.svc.cluster.local` | 8123 (HTTP), 9000 (Native) |
| ArangoDB | `arangodb.data-default.svc.cluster.local` | 8529 |

---

### 方法 1: Vault Agent Sidecar Injection (推荐)

> 适用于需要动态凭证或自动更新密码的场景

**Pod 配置示例：**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
  annotations:
    # 启用 Vault Agent 注入
    vault.hashicorp.com/agent-inject: "true"
    vault.hashicorp.com/role: "my-app"
    
    # PostgreSQL 密码
    vault.hashicorp.com/agent-inject-secret-pg: "secret/data/postgresql"
    vault.hashicorp.com/agent-inject-template-pg: |
      {{- with secret "secret/data/postgresql" -}}
      export PGPASSWORD="{{ .Data.data.password }}"
      {{- end }}
    
    # Redis 密码
    vault.hashicorp.com/agent-inject-secret-redis: "secret/data/redis"
    vault.hashicorp.com/agent-inject-template-redis: |
      {{- with secret "secret/data/redis" -}}
      export REDIS_PASSWORD="{{ .Data.data.password }}"
      {{- end }}
    
    # ClickHouse 密码
    vault.hashicorp.com/agent-inject-secret-clickhouse: "secret/data/clickhouse"
    vault.hashicorp.com/agent-inject-template-clickhouse: |
      {{- with secret "secret/data/clickhouse" -}}
      export CLICKHOUSE_PASSWORD="{{ .Data.data.password }}"
      {{- end }}

spec:
  serviceAccountName: my-app  # 必须有对应的 Vault K8s auth role
  containers:
    - name: app
      image: my-app:latest
      command: ["/bin/sh", "-c"]
      args:
        - |
          source /vault/secrets/pg
          source /vault/secrets/redis
          source /vault/secrets/clickhouse
          ./start-app.sh
```

**应用中读取密码：**

```python
# Python 示例
import os

# 从环境变量 (推荐)
pg_password = os.getenv('PGPASSWORD')

# 或直接读取文件
with open('/vault/secrets/pg', 'r') as f:
    exec(f.read())  # source 环境变量
```

---

### 方法 2: 直接连接字符串

> 适用于调试或简单脚本

```bash
# PostgreSQL
psql "postgresql://postgres:${PGPASSWORD}@postgresql.data-default.svc.cluster.local:5432/postgres"

# Redis
redis-cli -h redis-master.data-default.svc.cluster.local -a ${REDIS_PASSWORD}

# ClickHouse
clickhouse-client --host clickhouse.data-default.svc.cluster.local \
  --user default --password ${CLICKHOUSE_PASSWORD}

# ArangoDB
curl -u root:${ARANGO_PASSWORD} \
  http://arangodb.data-default.svc.cluster.local:8529/_api/version
```

---

### Vault 动态凭证流程 (PostgreSQL)

```mermaid
graph LR
    APP[L4 App + Vault Agent] -->|"vault read database/creds/app-readonly"| VAULT[Vault]
    VAULT -->|"CREATE ROLE + GRANT"| PG[(L3 PostgreSQL)]
    VAULT -->|"短期 user/pass"| APP
    APP -->|"使用动态凭证"| PG
```

**可用角色**：
- `database/creds/app-readonly` - SELECT 权限 (TTL: 1h)
- `database/creds/app-readwrite` - SELECT, INSERT, UPDATE, DELETE (TTL: 1h)

---

### 配置 Vault Kubernetes Auth Role

应用要使用 Vault Agent，需要先配置 K8s Auth Role：

```bash
# 1. 创建 ServiceAccount
kubectl create sa my-app -n default

# 2. 在 Vault 中创建 Role
vault write auth/kubernetes/role/my-app \
  bound_service_account_names=my-app \
  bound_service_account_namespaces=default \
  policies=db-readonly \
  ttl=1h

# 3. 创建 Policy
vault policy write db-readonly - <<EOF
path "secret/data/postgresql" { capabilities = ["read"] }
path "secret/data/redis" { capabilities = ["read"] }
path "secret/data/clickhouse" { capabilities = ["read"] }
path "database/creds/app-readonly" { capabilities = ["read"] }
EOF
```

---

## Vault Secrets 路径

| 数据库 | Vault 路径 | 字段 |
|--------|------------|------|
| PostgreSQL (L3) | `secret/data/postgresql` | `password` |
| Redis | `secret/data/redis` | `password` |
| ClickHouse | `secret/data/clickhouse` | `password` |
| ArangoDB | `secret/data/arangodb` | `root-password` |

## 相关文件

- Platform PG: [1.bootstrap/5.platform_pg.tf](../../1.bootstrap/5.platform_pg.tf)
- L3 Data: [3.data/](../../3.data/)
- Vault Config: [2.platform/2.vault.tf](../../2.platform/2.vault.tf)
