# ClickHouse SSOT

> **核心问题**：ClickHouse 如何配置和使用？

## 概述

| 属性 | 值 |
|------|------|
| **SSOT Key** | `db.clickhouse` |
| **层级** | L3 Data |
| **命名空间** | `data-<env>` (staging/prod) |
| **密码来源** | Vault (`secret/data/clickhouse`) |
| **StorageClass** | `local-path-retain` |
| **消费者** | L4 Apps (OLAP), SigNoz |

---

## 用途

| 用例 | 说明 |
|------|------|
| **OLAP 分析** | 大数据量聚合查询 |
| **日志存储** | SigNoz 后端 |
| **时序数据** | 指标/事件存储 |

---

## 端口

| 端口 | 协议 | 用途 |
|------|------|------|
| 8123 | HTTP | REST API |
| 9000 | Native | 高性能客户端 |

---

## 连接方式

**服务地址**：`clickhouse.data-<env>.svc.cluster.local`

### Vault Agent 配置

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "my-app"
  vault.hashicorp.com/agent-inject-secret-clickhouse: "secret/data/clickhouse"
  vault.hashicorp.com/agent-inject-template-clickhouse: |
    {{- with secret "secret/data/clickhouse" -}}
    export CLICKHOUSE_PASSWORD="{{ .Data.data.password }}"
    {{- end }}
```

### 直接连接

```bash
# Native 协议
clickhouse-client --host clickhouse.data-<env>.svc.cluster.local \
  --user default --password ${CLICKHOUSE_PASSWORD}

# HTTP API
curl "http://clickhouse.data-<env>.svc.cluster.local:8123/?query=SELECT%201"
```

---

## Vault Secrets 路径

| 路径 | 字段 |
|------|------|
| `secret/data/clickhouse` | `password` |

---

## 相关文件

- [3.data/](../../3.data/)
- [db.overview.md](./db.overview.md)
- [ops.observability.md](./ops.observability.md) (SigNoz 使用 ClickHouse)

---

## Used by

- [docs/ssot/db.overview.md](./db.overview.md)
- [docs/ssot/ops.observability.md](./ops.observability.md)
