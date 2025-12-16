# Platform PostgreSQL SSOT

> **核心问题**：Vault 和 Casdoor 的后端数据库如何管理？

## 概述

| 属性 | 值 |
|------|------|
| **层级** | L1 Bootstrap |
| **命名空间** | `platform` |
| **密码来源** | GitHub Secret (`VAULT_POSTGRES_PASSWORD`) |
| **StorageClass** | `local-path-retain` |
| **消费者** | Vault, Casdoor |

---

## 为什么在 L1？

1. **循环依赖**：Vault 需要 PG → 其他服务需要 Vault → 无法用 Vault 管理 Vault 的 PG 密码
2. **Trust Anchor**：L1 是信任锚点，允许打破 SSOT 规则
3. **隔离**：Platform PG 只服务于平台组件，不混用业务数据

---

## 部署配置

```hcl
# 1.bootstrap/5.platform_pg.tf
resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  namespace  = "platform"
  
  set_sensitive {
    name  = "auth.postgresPassword"
    value = var.vault_postgres_password
  }
}
```

---

## 连接方式

| 消费者 | 连接字符串来源 | 凭证类型 |
|--------|----------------|----------|
| Vault Pod | Helm values (L1 注入) | 静态 (GitHub Secret) |
| Casdoor Pod | Helm values (L1 注入) | 静态 (GitHub Secret) |

**服务地址**：`postgresql.platform.svc.cluster.local:5432`

---

## 备份策略

```bash
# VPS 上执行
pg_dump -h postgresql.platform.svc.cluster.local \
  -U postgres -d vault > /data/backups/platform_pg_$(date +%Y%m%d).sql
```

> TODO(backup): 配置定时备份 CronJob

---

## 相关文件

- [1.bootstrap/5.platform_pg.tf](../../1.bootstrap/5.platform_pg.tf)
- [platform.secrets.md](./platform.secrets.md)

---

