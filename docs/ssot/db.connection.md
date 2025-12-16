# 数据库连接 SSOT

> **核心问题**：应用如何连接数据库？

---

## K8s 服务发现

所有 L3 数据库通过 K8s Service 暴露：

| 数据库 | 服务地址 | 端口 |
|--------|----------|------|
| PostgreSQL | `postgresql.data-<env>.svc.cluster.local` | 5432 |
| Redis | `redis-master.data-<env>.svc.cluster.local` | 6379 |
| ClickHouse | `clickhouse.data-<env>.svc.cluster.local` | 8123 (HTTP), 9000 (Native) |
| ArangoDB | `arangodb.data-<env>.svc.cluster.local` | 8529 |

> `<env>` = `staging` 或 `prod`

---

## 方法 1: Vault Agent Sidecar Injection (推荐)

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

## 方法 2: 直接连接字符串

> 适用于调试或简单脚本

```bash
# PostgreSQL
psql "postgresql://postgres:${PGPASSWORD}@postgresql.data-<env>.svc.cluster.local:5432/postgres"

# Redis
redis-cli -h redis-master.data-<env>.svc.cluster.local -a ${REDIS_PASSWORD}

# ClickHouse
clickhouse-client --host clickhouse.data-<env>.svc.cluster.local \
  --user default --password ${CLICKHOUSE_PASSWORD}

# ArangoDB
curl -u root:${ARANGO_PASSWORD} \
  http://arangodb.data-<env>.svc.cluster.local:8529/_api/version
```

---

## Vault 动态凭证流程 (PostgreSQL)

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

## 配置 Vault Kubernetes Auth Role

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

---

## Used by（反向链接）

- [db.overview.md](./db.overview.md)
- [4.apps/README.md](../../4.apps/README.md)
