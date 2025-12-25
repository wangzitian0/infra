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

基于 **Digger Orchestrator** 与 **infra-flash 看板**。详见 [**Pipeline SSOT**](./docs/ssot/ops.pipeline.md)。

| Workflow | 职责 | 触发方式 |
| :--- | :--- | :--- |
| `ci.yml` | 统一入口：plan/apply/verify + 看板更新 | 合并后自动回报 |
| `bootstrap-deploy.yml` | L1 Bootstrap 计划/部署 + post-merge drift 追平 | 保持 L1 与 IaC 一致 |
| `claude.yml` | **AI 自动化审计** | 通过评论触发审计 |
| `e2e-tests.yml` | E2E 回归测试 | 合并后健康检查 |
| `docs-site.yml` | 文档站构建部署 | 文档可视化 |
| `readme-coverage.yml` | README 覆盖率检查 | 防止文档漂移 |

---
*Last updated: 2025-12-25*
# E2E Test 1766687963
