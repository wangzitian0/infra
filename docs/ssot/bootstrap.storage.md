# Bootstrap 存储层 SSOT

> **核心问题**：数据存在哪？StorageClass 如何配置？Platform PG 有什么特殊性？

---

## 组件概览

| 组件 | 职责 | 代码位置 |
|------|------|----------|
| **StorageClass** | PVC 存储类定义 | `bootstrap/4.storage.tf` |
| **Platform PG** | Vault/Casdoor 后端 | `bootstrap/4.platform_pg.tf` |

---

## 存储类型

| StorageClass | 提供者 | 用途 | Reclaim Policy |
|--------------|--------|------|----------------|
| `local-path` | K3s 内置 | 无状态/临时数据 | Delete |
| `local-path-retain` | 自定义 | 有状态服务 | Retain |
| `hostpath` | 自定义 | 持久数据 (`/data/`) | Retain |

### 数据目录

VPS 上的 `/data` 目录是所有持久化数据的根：

```
/data/
├── postgres/          # Platform PG 数据
├── vault/             # Vault 存储
├── backups/           # 备份归档
└── ...
```

---

## Platform PostgreSQL

### 用途

为控制面组件提供后端存储：
- **Vault**: 存储后端
- **Casdoor**: 用户/应用数据

### 与业务 PG 的区别

| 数据库 | 层级 | 用途 | 管理方式 |
|--------|------|------|----------|
| Platform PG | Bootstrap | Vault/Casdoor 后端 | 随 Bootstrap 部署 |
| Business PG | Data | 业务应用数据 | Per-env (staging/prod) |

> 详情见 [db.platform_pg.md](./db.platform_pg.md)

### 连接信息

- **Namespace**: `platform`
- **Service**: `platform-pg.platform.svc.cluster.local:5432`
- **认证**: 内部 K8s Secret

---

## 备份策略

### 数据库备份

1. 定时 `pg_dump` 到 `/data/backups/postgres/`
2. 计划同步到 R2: `r2://backups/platform-pg/`

### Terraform State

- **存储**: Cloudflare R2
- **路径**: `{env}/terraform.tfstate`

> 存储与备份详情见 [ops.storage.md](./ops.storage.md)

---

## 恢复流程

| 场景 | 恢复步骤 |
|------|----------|
| PVC 误删 | PV 仍保留 (Retain) → 重新绑定 PVC |
| VPS /data 丢失 | 从 R2 备份恢复 → 重新 apply |
| Platform PG 损坏 | 从 pg_dump 恢复 |

---

## Used by

- [docs/ssot/README.md](./README.md)
- [docs/ssot/core.md](./core.md)
- [docs/ssot/ops.storage.md](./ops.storage.md)
