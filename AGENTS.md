!!! AI 不可以自动修改本文件。当AI认为完工了，应当逐项检查本文档，所有要求都满足了才可以宣布完成。

# 🚨 强制规则（每次动手前必读）

| 规则 | 检查问题 |
|------|----------|
| 必关联 BRN | 你做的事情，必须能够关联到 BRN-004 或后续的 infra 相关 BRN |
| 先读后写 | 修改任何目录/文件前必须先阅读该层 README.md 或注释 |
| 必跑验证 | 改 Terraform 必须先 `terraform fmt` + `terraform plan` 确认无错误 |
| 必更文档 | 改动后同步更新对应的 README.md / AGENTS.md / change_log |
| 宁空勿错 | 配置不确定就留空或用占位符，不要填错的值 |
| 不要范围蔓延 | 当前 MVP 只做 k3s 引导，kubero/监控等是后续 |
| 不要过度设计 | 单 VPS 场景优先，不要引入不需要的复杂度 |

---

# 仓库定位

本仓库（infra）是 [BRN-004 EaaS 设计](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/origin/BRN-004.dev_test_prod_design.md) 的**基础设施层**实现。
## 第一原则
作为 infra 类型的 IaC repo，必须保证强一致性
- 本地和 CI 使用相同的命令
- 本地和 CI 使用相同的环境变量配置key
- 本地 plan 和 CI plan 的输出一致
- 被部署的资源一致，状态一致

## 设计原则
尽可能简化和正交，每一块功能只做一件事
参考 BRN-004 核心约束：**开源、自托管、单人强控、长期可扩展**

```
目标链条：
IaC (Terraform) → Runtime (k3s) → Apps (PEG-scaner)

当前范围（MVP）：
└── 使用 Terraform + GitHub Actions 在 VPS 上自动安装 k3s
└── 输出 kubeconfig，可连接并管理集群

后续演进：
└── kubero (Kubernetes 上的 PaaS)
└── kubero-ui (Web 控制台)
└── 应用部署、观测、Backstage
```

## 与 apps 仓库的关系

| 仓库 | 职责 | 依赖方向 |
|------|------|----------|
| **infra** (本仓库) | IaC 层：VPS、k3s、网络、存储 | ← 被依赖 |
| **apps** (子模块) | 应用层：PEG-scaner 业务代码 | → 依赖 infra |

- apps 作为 git submodule 存放在 `apps/` 目录
- **禁止软链**，保持单向依赖
- 引用 apps 文档必须用完整 GitHub URL

---

# 目录结构（必须与实际匹配）

```
.
├── AGENTS.md                          # AI Agent 长期规范（本文件）
├── README.md                          # 人类用户快速上手指南
├── .gitignore
├── apps/                              # PEG-scaner 子模块（只读引用）
├── docs/
│   ├── README.md                      # 文档导航
│   ├── 0.hi_zitian.md                 # 用户待办（5W1H）
│   └── change_log/
│       └── 2025-12-04.do_some_thing_important.md              # 变更日志
├── terraform/
│   ├── main.tf                        # 核心资源定义
│   ├── variables.tf                   # 变量定义
│   ├── outputs.tf                     # 输出定义
│   ├── backend.tf                     # R2 后端（bucket/endpoint 通过 -backend-config 传入）
│   ├── scripts/
│   │   └── install-k3s.sh.tmpl        # k3s 安装脚本模板
│   ├── output/                        # kubeconfig 输出（gitignored）
│   └── terraform.tfvars.example       # 本地 tfvars 模板
└── .github/
    └── workflows/
        └── deploy-k3s.yml             # CI 工作流
```

---

# Terraform 规范

## 变更流程

```
1. 修改 .tf 文件
2. terraform fmt -check（格式化检查）
3. terraform plan（预览变更）
4. 确认无误后更新文档 + change_log
5. PR review 或直接 push main 触发 CI
```

## State 管理

- **后端**：Cloudflare R2（S3 兼容，无锁）
- **配置**：`backend.tf` 入库，bucket/endpoint 通过 `-backend-config` 传入
- **凭据**：`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` 通过环境变量或 CI Secrets

## 敏感文件（不入库）

| 文件 | 用途 |
|------|------|
| `terraform/terraform.tfvars` | 本地变量值 |
| `*.pem` / `*.key` | SSH 私钥 |

---

# 文档规范

## 文档类型

| 文档 | 用途 | 谁写 |
|------|------|------|
| `docs/0.hi_zitian.md` | 用户待办、决策点（5W1H） | AI 提问，用户填答案 |
| `docs/change_log/*.md` | 变更记录 | AI 每次改动后更新 |
| `README.md` | 人类快速上手 | AI 维护 |
| `AGENTS.md` | AI Agent 长期规范 | 用户定义，AI 只读 |

## 变更记录格式

```markdown
# YYYY-MM-DD — 标题

## 做了什么
- 改动点 1
- 改动点 2

## 如何验证
1. 验证步骤

## 后续建议
- 待办事项
```

---

# CI/CD 规范

## GitHub Actions 工作流

路径：`.github/workflows/deploy-k3s.yml`

### 触发条件
- Push to main（terraform/** 或 workflow 本身变更）
- 手动 workflow_dispatch

### Secrets 配置

| 类别 | Secret 名称 | 必填 |
|------|------------|------|
| R2 | `AWS_ACCESS_KEY_ID` | ✅ |
| R2 | `AWS_SECRET_ACCESS_KEY` | ✅ |
| R2 | `R2_BUCKET` | ✅ |
| R2 | `R2_ACCOUNT_ID` | ✅ |
| VPS | `VPS_HOST` | ✅ |
| VPS | `VPS_SSH_KEY` | ✅ |
| VPS | `VPS_USER` | ❌ (默认 root) |
| VPS | `VPS_SSH_PORT` | ❌ (默认 22) |
| k3s | `K3S_API_ENDPOINT` | ❌ (默认 VPS_HOST) |
| k3s | `K3S_CHANNEL` | ❌ (默认 stable) |
| k3s | `K3S_VERSION` | ❌ |
| k3s | `K3S_CLUSTER_NAME` | ❌ (默认 truealpha-k3s) |

### 工作流步骤

```
Checkout → Setup Terraform → Render tfvars → fmt → init → plan → apply → Pull kubeconfig → Smoke test → Upload artifact
```

---

# 评分机制

| 维度 | 权重 | 标准 |
|------|------|------|
| **Impact** | 60% | k3s 能装成功吗？kubeconfig 能用吗？ |
| **Quality** | 25% | terraform plan 通过？文档更新了？ |
| **Safety** | 15% | 敏感信息没泄露？权限最小化？ |

---

# 演进路线

```
Phase 1 (当前): k3s 引导 ✅
├── Terraform + GitHub Actions
├── 单节点 k3s
└── kubeconfig 输出

Phase 2: kubero + UI
├── Helm chart 部署 kubero
├── kubero-ui 安装
└── DNS 配置

Phase 3: 应用上线
├── PEG-scaner 部署
├── 域名绑定
└── TLS 证书

Phase 4: 观测 + 平台
├── SigNoz / 监控
├── Backstage (可选)
└── 多 VPS 扩展
```

---

# 参考文档

- [BRN-004: EaaS 设计理念](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/origin/BRN-004.dev_test_prod_design.md)
- [IRD-004: 环境基础设施规范](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/specs/infra/IRD-004.env_eaas_infra.md)
- [TRD-004: 实现技术规范](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/specs/tech/TRD-004.env_eaas_implementation.md)
