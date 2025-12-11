# SSOT 文档索引

> **Single Source of Truth** - 话题式架构文档

本目录按话题组织，回答"整个系统的密钥/流程/数据库能力如何分拆到组件"。

## 目录

| 文件 | 核心问题 | 关键内容 |
|------|----------|----------|
| [dir.md](./dir.md) | 项目结构 | 目录树、Layer 定义、Namespace 注册 |
| [k3s.md](./k3s.md) | 集群与 PaaS | K3s、StorageClass、Kubero、Namespace 规范 |
| [vars.md](./vars.md) | 非密钥变量 | TF_VAR 列表、默认值、Feature Flags |
| [secrets.md](./secrets.md) | 密钥管理 | 四层模型、1Password 清单、Vault Path |
| [pipeline.md](./pipeline.md) | 流程汇总 | L1 手动 vs L2+ GitOps、灾备 |
| [db.md](./db.md) | 数据库分布 | Platform PG (L1) vs Business DBs (L3) |
| [auth.md](./auth.md) | 统一认证 | Casdoor SSO、服务接入矩阵 |
| [network.md](./network.md) | 域名规则 | Internal vs Env 模式 |

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
│  (Vault, SSO)    │  │  (业务数据库)     │  │  (业务应用)       │
│  依赖: L1 PG     │  │  依赖: L2 Vault   │  │  依赖: L2 + L3   │
└──────────────────┘  └──────────────────┘  └──────────────────┘
```

## 相关文档

- [AGENTS.md](../../AGENTS.md) - AI 行为准则
- [BRN-008](../project/BRN-008.md) - 本次重构设计文档
