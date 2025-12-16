# SSOT 文档索引

> **Single Source of Truth** - 话题式架构文档

本目录按话题组织，回答"整个系统的密钥/流程/数据库能力如何分拆到组件"。

---

## Core - 核心 (必读)

| 文件 | 核心问题 | 关键内容 |
|------|----------|----------|
| [core.dir.md](./core.dir.md) | 项目结构 | 目录树、Layer 定义、Namespace 注册 |
| [core.env.md](./core.env.md) | 环境模型 | environment/workspace/namespace/state key/域名/vars 统一规则 |
| [core.vars.md](./core.vars.md) | 非密钥变量 | TF_VAR 列表、默认值、Feature Flags |

---

## Platform - 平台层

| 文件 | 核心问题 | 关键内容 |
|------|----------|----------|
| [platform.auth.md](./platform.auth.md) | 统一认证 | Casdoor SSO 门户覆盖与 1Password/Vault 密钥策略 |
| [platform.network.md](./platform.network.md) | 域名规则 | Internal vs Env 模式 |
| [platform.secrets.md](./platform.secrets.md) | 密钥管理 | 四层模型、1Password 清单、Vault（SSOT） |
| [platform.ai.md](./platform.ai.md) | AI 接入 | OpenRouter、变量/密钥、注入方式 |

---

## Data - 数据层

| 文件 | 核心问题 | 关键内容 |
|------|----------|----------|
| [db.overview.md](./db.overview.md) | 数据库分布总览 | 各层数据库矩阵 |
| [db.platform_pg.md](./db.platform_pg.md) | Platform PG (L1) | Vault/Casdoor 后端 |
| [db.business_pg.md](./db.business_pg.md) | Business PG (L3) | 业务应用数据库 |
| [db.redis.md](./db.redis.md) | Redis (L3) | 缓存、消息队列 |
| [db.clickhouse.md](./db.clickhouse.md) | ClickHouse (L3) | OLAP、SigNoz |
| [db.arangodb.md](./db.arangodb.md) | ArangoDB (L3) | 图数据库 |

---

## Ops - 运维

| 文件 | 核心问题 | 关键内容 |
|------|----------|----------|
| [ops.pipeline.md](./ops.pipeline.md) | 流程汇总 | PR CI + Atlantis autoplan + deploy-k3s |
| [ops.recovery.md](./ops.recovery.md) | 故障恢复 | Secrets 恢复、Vault Token、State Lock |
| [ops.storage.md](./ops.storage.md) | 存储与备份 | /data、StorageClass、R2 备份与同步 |
| [ops.observability.md](./ops.observability.md) | 日志与监控 | SigNoz、OTel、数据保留 |
| [ops.alerting.md](./ops.alerting.md) | 告警 | 规则分级、通知通道、值班策略 |

---

## 维护约定（SSOT → Wikipedia 风格）

- **固定格式**：每个 SSOT 页面最后包含 `Used by（反向链接）`，用于双向链接（类似 "What links here"）。
- **避免漂移**：一处信息 SSOT 化后，其他文档只保留摘要并链接到该 SSOT 页面。
- **稳定链接**：如需调整路径，优先保留旧路径的入口页（redirect），避免外部引用 404。
- **TODO 标注**：未完成事项使用 `> TODO(module): 描述` 格式标注。

---

## 层级架构

```
┌─────────────────────────────────────────────────────────────┐
│  L1 Bootstrap (Trust Anchor - 打破 SSOT)                    │
├─────────────────────────────────────────────────────────────┤
│  • K3s Cluster, Platform PostgreSQL, Atlantis CI           │
│  • 密钥来源：GitHub Secrets                                  │
└─────────────────────────────────────────────────────────────┘
         ▲ 不依赖任何其他层
         │
═════════╪═════════════════════════════════════════════════════
         ▼
┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐
│  L2 Platform     │  │  L3 Data         │  │  L4 Apps         │
│  (Vault, SSO)    │  │  (业务数据库)     │  │  (Kubero, SigNoz)│
│  依赖: L1 PG     │  │  依赖: L2 Vault   │  │  依赖: L2 + L3   │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

---

## 相关文档

- [AGENTS.md](../../AGENTS.md) - AI 行为准则
- [docs/project/](../project/) - 设计文档 (BRN-*)
