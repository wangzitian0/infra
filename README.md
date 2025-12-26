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

基于 **6-Actions 架构**：每个 action 可手动触发，部分自动触发。详见 [**Pipeline SSOT**](./docs/ssot/ops.pipeline.md)。

### 6 个 CI Actions

| Action | 包含操作 | PR Auto | Post-merge Auto | Manual |
|--------|---------|---------|----------------|--------|
| **check** | fmt + validate | ✅ | ✅ | `/check` |
| **bootstrap-plan** | Bootstrap plan | ✅ | ✅ | `/bootstrap-plan` |
| **plan** | TF + Digger plan | ✅ | ✅ | `/plan` |
| **bootstrap-apply** | Bootstrap apply | - | ✅ | `/bootstrap-apply` |
| **apply** | TF + Digger apply | - | ✅ | `/apply` |
| **e2e** | E2E tests | - | ✅ | `/e2e` |

### 工作流程

**PR 阶段**：
```
check → bootstrap-plan → plan → [Review] → Merge
```

**Post-merge 自动部署**：
```
check → bootstrap-plan + plan → bootstrap-apply + apply → e2e
```

**手动触发** (任意时刻)：
```
/check, /bootstrap-plan, /plan
/bootstrap-apply, /apply, /e2e
/help
```

g
---
*Last updated: 2025-12-25*
# Test Digger Integration
