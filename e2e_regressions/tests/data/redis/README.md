# Redis SSOT

> **核心问题**：Redis 如何配置和使用？

## 概述

| 属性 | 值 |
|------|------|
| **SSOT Key** | `db.redis` |
| **层级** | L3 Data |
| **命名空间** | `data-<env>` (staging/prod) |
| **密码来源** | Vault (`secret/data/redis`) |
| **StorageClass** | `local-path-retain` |
| **消费者** | L4 Apps (Cache, Session, Queue) |

---

## 用途

| 用例 | 说明 |
|------|------|
| **缓存** | 热点数据、Session |
| **消息队列** | Redis Streams (轻量级) |
| **分布式锁** | Redlock |

---

## 连接方式

**服务地址**：`redis-master.data-<env>.svc.cluster.local:6379`

### Vault Agent 配置

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

### 直接连接

```bash
redis-cli -h redis-master.data-<env>.svc.cluster.local -a ${REDIS_PASSWORD}
```

---

## Vault Secrets 路径

| 路径 | 字段 |
|------|------|
| `secret/data/redis` | `password` |

---

## 相关文件

- [3.data/](../../3.data/)
- [db.overview.md](./db.overview.md)

---

## Used by

- [docs/ssot/db.overview.md](./db.overview.md)
