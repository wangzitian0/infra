# cc_infra

单 VPS、自托管的基础设施仓库（Terraform + k3s + Digger），遵循 **SSOT (Single Source of Truth)** 架构原则。

## 🚀 Quick Start

- **AI 行为准则 / SOP**：[`AGENTS.md`](./AGENTS.md)
- **SSOT 技术参考手册**：[`docs/ssot/README.md`](./docs/ssot/README.md)
- **开发者接入指南**：[`docs/onboarding/README.md`](./docs/onboarding/README.md)
- **当前上下文**：[`0.check_now.md`](./0.check_now.md)

## 🏗️ 模块化架构

本仓库采用四层分层设计：

1.  **[Bootstrap (L1)](./bootstrap/README.md)**: 基础集群与 GitOps 引导 (k3s, Digger, DNS/Cert)。
2.  **[Platform (L2)](./platform/README.md)**: 统一控制面 (Vault, Casdoor, PaaS, SigNoz)。
3.  **[Data (L3)](./envs/README.md)**: 业务数据库面 (PostgreSQL, Redis, ClickHouse, ArangoDB)。
4.  **[Apps (L4)](./apps/README.md)**: 业务应用层。

## 🤖 自动化工作流 (CI/CD)

基于 **双轨 CI 架构**：自动 CI checks + 手动 Digger 命令。详见 [**Pipeline SSOT**](./docs/ssot/ops.pipeline.md)。

### 快速命令

| 命令 | 触发方式 | 用途 |
|:-----|:---------|:-----|
| 自动 plan | PR 创建 | 自动运行 terraform plan (CI check) |
| 自动 apply | PR 合并到 main | 自动部署所有变更 (CI check) |
| `/plan` | PR 评论 | 手动触发 plan (Digger 编排) |
| `/apply` | PR 评论 | 手动触发 apply (Digger 编排) |
| `digger plan -p platform` | PR 评论 | Plan 指定项目 |
| `digger apply -p platform` | PR 评论 | Apply 指定项目 |
| `/bootstrap plan\|apply` | PR 评论 | L1 层管理 |
| `/e2e` | PR 评论 | 触发 E2E 测试 |
| `/help` | PR 评论 | 显示帮助 |

### 工作流程

**标准 PR 流程**：
```
1. 创建 PR → 自动 terraform-plan (CI check)
2. Review plan 输出
3. (可选) /apply 提前测试某个项目
4. Approve & Merge → 自动 terraform-apply
```

**紧急单项目修复**：
```
评论: digger apply -p platform
→ 只 apply 指定项目，不影响其他
```

---
*Last updated: 2025-12-25*
