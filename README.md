# codex_infra

单 VPS、自托管的基础设施仓库（Terraform + k3s + Digger），按职责拆分为不同模块。

## Start Here

- AI 入口 / SOP：[`AGENTS.md`](./AGENTS.md)
- 当前上下文：[`0.check_now.md`](./0.check_now.md)
- 目录结构 SSOT：[`docs/ssot/core.dir.md`](./docs/ssot/core.dir.md)
- 话题 SSOT 索引：[`docs/ssot/README.md`](./docs/ssot/README.md)
- Layer 文档：[`bootstrap/README.md`](./bootstrap/README.md) · [`platform/README.md`](./platform/README.md) · [`envs/staging/data/README.md`](./envs/staging/data/README.md) · [`envs/prod/data/README.md`](./envs/prod/data/README.md)
- GitHub 自动化入口：[`.github/README.md`](./.github/README.md) · [`.github/workflows/README.md`](./.github/workflows/README.md)

## 模块化架构 (Terragrunt)

本仓库使用 **Terragrunt** 管理配置，按职责分工：
- **[tools/](./tools)**: Shared infrastructure scripts, CI pipelines, and automation tools.
- **Bootstrap**: 基础集群与 GitOps 引导（k3s, Digger, DNS/Cert）。
- **Platform**: 统一控制面（Vault, SSO, PaaS Controller, Observability）。
- **Data**: 业务数据库面（Per-env, 依赖 Platform 认证）。

详见各层 README 中的使用说明。

## GitHub Automation（CI/CD）

基于 **`infra-flash` 运维看板** 打造的闭环流水线。详见：[`docs/ssot/ops.pipeline.md`](./docs/ssot/ops.pipeline.md)。

| Workflow | 职责 | 核心价值 |
| :--- | :--- | :--- |
| `terraform-plan.yml` | CI 静态检查 + 看板骨架创建 | 每个 Commit 独立的 **SSOT 仪表盘** |
| `infra-flash-update.yml` | Orchestrator 结果搬运 | Plan/Apply 输出实时同步至看板 |
| `claude-code-review.yml` | **AI 自动化审计** | Apply 成功后自动执行审计 |
| `infra-commands.yml` | 指令分发器 (`dig`, `help`) | 通过评论手动触发探测 |
| `deploy-bootstrap.yml` | Bootstrap 初始引导 (手动) | k3s, Digger 等基础组件 |

---
*Last updated: 2025-12-24*
