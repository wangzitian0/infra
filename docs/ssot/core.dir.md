# 目录结构 SSOT

> **核心问题**：代码在哪里？负责什么？

---

## 层级架构

```
L0 Tools     ─  0.tools/, docs/          ─  脚本、文档
L1 Bootstrap ─  1.bootstrap/             ─  K3s, Atlantis, DNS/Cert, Platform PG (无依赖)
L2 Platform  ─  2.platform/              ─  Vault, Casdoor, Dashboard (全局 1 份)
L3 Data      ─  3.data/                  ─  业务数据库 (per-env, N 份)
L4 Apps      ─  4.apps/                  ─  Kubero, SigNoz (控制面 1 份，通过 Pipeline 管理多 env)
```

### 层级职责详解

| 层级 | 核心职责 | 部署份数 | 多环境策略 |
|------|----------|---------|-----------|
| **L1 Bootstrap** | Trust Anchor + 工具箱 | **1 套** | 无依赖，CI 直接部署 |
| **L2 Platform** | 基建控制面 (密钥/SSO) | **1 套** | Atlantis `default` workspace |
| **L3 Data** | 数据面 (业务 DB) | **N 套** | Per-env workspace (staging/prod) |
| **L4 Apps** | 应用控制面 (PaaS/Observability) | **1 套** | Kubero Pipeline/Phase 管理多 env |

### L4 多环境管理

L4 的 Kubero 是单控制面，通过 Pipeline/Phase 管理多 app × 多 env：

```
Kubero (单控制面)
├── Pipeline: app-a
│   ├── phase: staging → namespace: apps-staging
│   └── phase: prod    → namespace: apps-prod
└── Pipeline: app-b
    ├── phase: staging → namespace: apps-staging
    └── phase: prod    → namespace: apps-prod
```

### 依赖 vs 数据流

```
依赖方向 (部署顺序):      数据流方向 (日志/指标):
L1 → L2 → L3 → L4          L1 ──┐
                           L2 ──┼──→ SigNoz (L4)
                           L3 ──┤
                           L4 ──┘
```

> 可观测性数据从 L1-L4 流向 SigNoz，这是**数据流**而非代码依赖，不破坏 DAG。

---


## 完整目录树

```
root/
├── AGENTS.md                    # (!) AI 行为准则
├── 0.check_now.md               # (!) 当前 sprint
├── atlantis.yaml                # (!) GitOps 配置
├── README.md                    # (!) 项目入口
│
├── 0.tools/
│   ├── README.md                # 脚本索引
│   ├── check-readme-coverage.sh # README 覆盖检查
│   ├── preflight-check.sh       # Helm URL 验证
│   └── migrate-state.sh         # State 迁移
│
├── docs/
│   ├── README.md                # (!) 设计概念
│   ├── ssot/
│   │   ├── README.md            # (!) SSOT 索引
│   │   ├── core.dir.md          # (!) 本文件
│   │   ├── core.env.md          # (!) 环境模型
│   │   ├── core.vars.md         # 变量定义
│   │   ├── platform.auth.md     # 认证架构
│   │   ├── platform.secrets.md  # 密钥管理
│   │   ├── platform.network.md  # 网络/域名
│   │   ├── platform.ai.md       # AI 接入
│   │   ├── db.*.md              # 各数据库 SSOT
│   │   ├── ops.pipeline.md      # (!) 部署流程
│   │   ├── ops.standards.md     # (!) 运维标准 (Guards/Admission)
│   │   ├── ops.recovery.md      # 故障恢复
│   │   ├── ops.storage.md       # 存储备份
│   │   ├── ops.observability.md # 可观测
│   │   └── ops.alerting.md      # 告警
│   ├── project/
│   │   ├── README.md            # BRN 索引
│   │   └── BRN-*.md             # 设计文档
│   ├── change_log/              # 变更历史
│   └── deep_dives/              # 深度分析
│
├── .github/
│   └── workflows/
│       ├── README.md            # CI 索引
│       ├── terraform-plan.yml   # (!) TF 验证
│       ├── deploy-k3s.yml       # (!) K3s 部署
│       └── infra-commands.yml   # Infra Commands (review, dig)
│
├── 1.bootstrap/                 # L1: GitHub Actions 部署
│   ├── README.md                # (!) L1 文档
│   ├── backend.tf               # R2 后端
│   ├── providers.tf             # Provider
│   ├── variables.tf             # 变量定义
│   ├── locals.tf                # 本地变量
│   ├── 1.k3s.tf                 # K3s 安装
│   ├── 2.atlantis.tf            # Atlantis
│   ├── 3.dns_and_cert.tf        # DNS + Cert-Manager
│   ├── 4.storage.tf             # 存储类
│   └── 5.platform_pg.tf         # Platform PostgreSQL
│
├── 2.platform/                  # L2: Atlantis 部署
│   ├── README.md                # (!) L2 文档
│   ├── backend.tf               # R2 后端
│   ├── providers.tf             # Provider
│   ├── variables.tf             # 变量定义
│   ├── locals.tf                # 本地变量
│   ├── 1.portal-auth.tf         # Portal SSO Gate
│   ├── 2.secret.tf              # Vault
│   ├── 3.dashboard.tf           # K8s Dashboard
│   └── 5.casdoor.tf             # Casdoor SSO
│
├── 3.data/                      # L3: Atlantis 部署 (per-env)
│   ├── README.md                # (!) L3 文档
│   └── *.tf                     # Redis, PG, ClickHouse, ArangoDB
│
├── 4.apps/                      # L4: Atlantis 部署 (per-env)
│   ├── README.md                # (!) L4 文档
│   ├── 1.kubero.tf              # Kubero PaaS
│   └── *.tf                     # 业务应用
│
└── envs/                        # 环境配置
    ├── README.md                # tfvars 指南
    ├── staging.tfvars.example   # Staging 模板
    └── prod.tfvars.example      # Prod 模板
```

**图例**：`(!)` = SSOT / 关键文件

---

## Namespace 规则

| 层级 | Namespace | 组件 | 部署模式 |
|------|-----------|------|---------|
| L1 | `kube-system` | K3s 系统组件 | 单例 |
| L1 | `bootstrap` | Atlantis | 单例 |
| L2 | `platform` | Vault, Dashboard, Casdoor | 单例 |
| L3 | `data-staging` | Staging 数据库 | per-env |
| L3 | `data-prod` | Prod 数据库 | per-env |
| L4 控制面 | `kubero` | Kubero UI | 单例 |
| L4 控制面 | `kubero-operator-system` | Kubero Operator | 单例 |
| L4 控制面 | `observability` | SigNoz, OTel Collector | 单例 |
| L4 工作负载 | `apps-staging` | Staging 应用 (Kubero Pipeline 部署) | per-env |
| L4 工作负载 | `apps-prod` | Prod 应用 (Kubero Pipeline 部署) | per-env |

> **持久化**: 
> - L1/L3 有状态组件用 PVC (`local-path-retain`)
> - L2 控制面无状态（依赖 L1 Platform PG）
> - L4 控制面存储需求由 **L3 提供**（如 Kubero 的 MongoDB/PG 部署在 L3 data namespace）

> **健康检查**: 见 [ops.pipeline.md](./ops.pipeline.md#8-健康检查分层)

---

