# 存储与文件系统 SSOT

> **核心问题**：状态放哪？PV/对象存储怎么选？备份如何同步到本地或 Cloudflare？

## 存储类型

| 类型 | SSOT 文件/位置 | 用途 | 特点 |
|------|----------------|------|------|
| **本地 PVC (`local-path`)** | K3s 内置 | 无状态/临时数据 | 删除即回收 |
| **本地 PVC (`local-path-retain`)** | `1.bootstrap/4.storage.tf` | 有状态服务 | PV Retain，需人工清理 |
| **对象存储（Cloudflare R2）** | `1.bootstrap/backend.tf` | TF state / 备份归档 | S3 兼容、低成本 |

## 层级数据落点

| 层级 | 数据 | 存储位置 | 备份 |
|------|------|----------|------|
| **L1 Bootstrap** | k3s/平台 PG/Vault 等持久卷 | VPS `/data` → PVC | `pg_dump` 到 `/data/backups` |
| **L3 Data** | 业务 PG/Redis/Neo4j/ClickHouse | PVC (`local-path-retain`) | 按库定时 dump |
| **L4 Apps** | 应用容器 | 默认无状态 | 通过 L3 或 R2 持久化 |

> 目录与持久化职责见 `docs/ssot/dir.md`。

## 备份与同步策略（MVP）

### 1. Terraform State

- **SSOT**：Cloudflare R2（已落地）。
- **路径**：`{env}/terraform.tfstate`

### 2. 数据库备份

1. 定时 `pg_dump` / `neo4j-admin dump` / `redis-cli --rdb` 到 VPS `/data/backups/{service}/`。
2. **同步到 R2**（计划）：用 `restic` 或 `rclone` 推送到 `r2://backups/{env}/`。

### 3. SSOT 文档快照

- **Git** 是唯一真源；为了灾备，可定期把 `docs/ssot/` 目录打包同步到 R2。
- 计划在 `0.tools/` 增加 `ssot-sync.sh`（未落地）。

## 恢复流程（摘要）

| 场景 | 恢复 |
|------|------|
| PVC 误删 | PV 仍保留（Retain）→ 重新绑定 PVC |
| VPS /data 丢失 | 从 R2 备份恢复 → 重新 apply Helm |
| 单机容量不足 | 扩容 PVC 或拆分到独立 VPS |

## 实施状态

| 项目 | 状态 |
|------|------|
| `/data` + StorageClass | ✅ L1 已落地 |
| 数据库定时备份 | ⏳ 未落地 |
| R2 备份同步 | ⏳ 未落地 |

## 相关文件

- 存储类：[core.dir.md](./core.dir.md)
- 数据落点：[db.overview.md](./db.overview.md)
- R2 backend：`1.bootstrap/backend.tf`

---

## Used by（反向链接）

- [README.md](./README.md)
- [db.overview.md](./db.overview.md)
- [ops.recovery.md](./ops.recovery.md)
