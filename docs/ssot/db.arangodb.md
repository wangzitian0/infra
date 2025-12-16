# ArangoDB SSOT

> **核心问题**：ArangoDB 如何配置和使用？

## 概述

| 属性 | 值 |
|------|------|
| **层级** | L3 Data |
| **命名空间** | `data-<env>` (staging/prod) |
| **密码来源** | Vault (`secret/data/arangodb`) |
| **StorageClass** | `local-path-retain` |
| **消费者** | L4 Apps (Graph) |

---

## 用途

| 用例 | 说明 |
|------|------|
| **图数据库** | 关系网络、知识图谱 |
| **多模型** | 文档 + 图 + Key-Value |

---

## 连接方式

**服务地址**：`arangodb.data-<env>.svc.cluster.local:8529`

### Vault Agent 配置

```yaml
annotations:
  vault.hashicorp.com/agent-inject: "true"
  vault.hashicorp.com/role: "my-app"
  vault.hashicorp.com/agent-inject-secret-arangodb: "secret/data/arangodb"
  vault.hashicorp.com/agent-inject-template-arangodb: |
    {{- with secret "secret/data/arangodb" -}}
    export ARANGO_PASSWORD="{{ .Data.data.root-password }}"
    {{- end }}
```

### 直接连接

```bash
# HTTP API
curl -u root:${ARANGO_PASSWORD} \
  http://arangodb.data-<env>.svc.cluster.local:8529/_api/version

# ArangoShell
arangosh --server.endpoint tcp://arangodb.data-<env>.svc.cluster.local:8529 \
  --server.username root --server.password ${ARANGO_PASSWORD}
```

---

## Vault Secrets 路径

| 路径 | 字段 |
|------|------|
| `secret/data/arangodb` | `root-password` |

---

## 相关文件

- [3.data/](../../3.data/)
- [db.connection.md](./db.connection.md)

---

