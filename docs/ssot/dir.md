# 目录结构 SSOT

> **核心问题**：代码在哪里？负责什么？

---

## 层级架构

```
L0 Tools     ─  0.tools/, docs/          ─  脚本、文档
L1 Bootstrap ─  1.bootstrap/             ─  K3s, Atlantis, DNS/Cert, PG
L2 Platform  ─  2.platform/              ─  Vault, Dashboard, Kubero, Casdoor
L3 Data      ─  3.data/                  ─  业务数据库 (per-env)
L4 Apps      ─  4.apps/                  ─  业务应用 (per-env)
```

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
│   ├── preflight-check.sh       # Helm URL 验证
│   └── migrate-state.sh         # State 迁移
│
├── docs/
│   ├── README.md                # (!) 设计概念
│   ├── ssot/
│   │   ├── README.md            # (!) SSOT 索引
│   │   ├── dir.md               # (!) 本文件
│   │   ├── env.md               # (!) 环境模型
│   │   ├── pipeline.md          # (!) 部署流程
│   │   ├── network.md           # 网络/域名
│   │   ├── db.md                # 数据库分布
│   │   ├── k3s.md               # K3s/PaaS
│   │   ├── vars.md              # 变量定义
│   │   ├── secrets.md           # 密钥管理
│   │   └── auth.md              # 认证架构
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
│       └── claude.yml           # AI Review
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
│   ├── 4.kubero.tf              # Kubero PaaS
│   └── 5.casdoor.tf             # Casdoor SSO
│
├── 3.data/                      # L3: Atlantis 部署 (per-env)
│   ├── README.md                # (!) L3 文档
│   └── *.tf                     # Redis, Neo4j, PG, ClickHouse
│
├── 4.apps/                      # L4: Atlantis 部署 (per-env)
│   ├── README.md                # (!) L4 文档
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

| 层级 | Namespace | 组件 |
|------|-----------|------|
| L1 | `kube-system` | K3s 系统组件 |
| L1 | `bootstrap` | Atlantis |
| L2 | `platform` | Vault, Dashboard, Casdoor |
| L2 | `kubero` | Kubero UI |
| L2 | `kubero-operator-system` | Kubero Operator |
| L3 | `data-staging` | Staging 数据库 |
| L3 | `data-prod` | Prod 数据库 |
| L4 | `apps-staging` | Staging 应用 |
| L4 | `apps-prod` | Prod 应用 |

---

## 持久化

| 层级 | 组件 | 存储 |
|------|------|------|
| L1 | PostgreSQL | PVC on `/data` |
| L2 | Vault | 使用 L1 PG |
| L2 | Casdoor | 使用 L1 PG |
| L3 | 业务 DB | PVC on `/data` |
| L4 | Apps | 无状态，用 L3 |

---

## 组件健康检查规范

### 强制要求

| 检查类型 | 适用场景 | 强制 |
|----------|----------|------|
| **initContainer** | 有外部依赖的 Pod | ✅ 必须 (120s 超时) |
| **Probes** | 所有长期运行 Pod | ✅ 必须 |
| **validation** | 敏感变量（密码/密钥/URL） | ✅ 必须 |
| **precondition** | 依赖其他 TF 资源的组件 | ✅ 必须 |
| **Helm timeout** | 所有 Helm release | ✅ 必须 (300s) |
| **postcondition** | Helm release | 建议 |

### 覆盖度矩阵

| 层级 | 组件 | 依赖 | initContainer | Probes | validation | precondition | timeout |
|------|------|------|---------------|--------|------------|--------------|---------|
| **L1** | k3s | 无 | N/A | N/A | N/A | N/A | 5m |
| | Atlantis | k3s | N/A | ✅ R+L | ✅ | ✅ | 300s |
| | DNS/Cert | k3s | N/A | N/A | ✅ | N/A | 300s |
| | Storage | k3s | N/A | N/A | N/A | N/A | 2m |
| | Platform PG | storage | N/A | ✅ Helm | ✅ | ✅ | 300s |
| **L2** | Vault | PG | ✅ 120s | ✅ R+L | ✅ | ✅ | 300s |
| | Casdoor | PG | ✅ 120s | ✅ S+R+L | ✅ | ✅ | 300s |
| | Portal-Auth | Casdoor | ✅ 120s | ✅ R+L | ✅ | ✅ | 300s |
| | Dashboard | namespace | N/A | ✅ Helm | N/A | N/A | 300s |
| | Kubero | namespace | N/A | ✅ R+L | N/A | N/A | N/A (manifest) |
| | Vault-DB | Vault | N/A | N/A | ✅ | ✅ | N/A |
| **L3** | L3 Postgres | Vault KV | ✅ 120s | ✅ Helm | ✅ | ✅ | 300s |

**图例**：R=readiness, L=liveness, S=startup, Helm=Chart 默认, N/A=不适用, 120s=initContainer 超时

---

## 相关文件

| 文件 | 用途 |
|------|------|
| `docs/ssot/env.md` | 环境模型 |
| `docs/ssot/pipeline.md` | 部署流程 |

---

## Used by（反向链接）

- [docs/ssot/README.md](./README.md)
- [README.md](../../README.md)
- [docs/README.md](../README.md)
- [docs/dir.md](../dir.md)
- [3.data/README.md](../../3.data/README.md)
- [docs/project/BRN-008.md](../project/BRN-008.md)
- [docs/ssot/storage.md](./storage.md)
