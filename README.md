# codex_infra

单 VPS、自托管的基础设施仓库（Terraform + k3s + Atlantis），按 L0–L4 分层组织。

## Start Here

- AI 入口：[`AGENTS.md`](./AGENTS.md)
- 当前上下文：[`0.check_now.md`](./0.check_now.md)
- 文档站点（MkDocs）：[`mkdocs.yml`](./website/mkdocs.yml)（仅使用 git 管控的 `*.md`；CI: [`.github/workflows/docs-site.yml`](./.github/workflows/docs-site.yml)）
- 目录结构 SSOT：[`docs/ssot/core.dir.md`](./docs/ssot/core.dir.md)
- 话题 SSOT 索引：[`docs/ssot/README.md`](./docs/ssot/README.md)
- Layer 文档：[`0.tools/README.md`](./0.tools/README.md) · [`1.bootstrap/README.md`](./1.bootstrap/README.md) · [`2.platform/README.md`](./2.platform/README.md) · [`3.data/README.md`](./3.data/README.md) · [`4.apps/README.md`](./4.apps/README.md)
- GitHub 自动化入口：[`.github/README.md`](./.github/README.md) · [`.github/workflows/README.md`](./.github/workflows/README.md)
- README 保护检查：新增 `scripts/check-readme-coverage.sh` 与 [`readme-coverage.yml`](.github/workflows/readme-coverage.yml)，每次变更要求 ≥80% 的目录同步更新对应 `README.md`。

## GitHub Automation（CI/CD）

基于 **`infra-flash` 运维看板** 打造的闭环流水线。详见：[`docs/ssot/ops.pipeline.md`](./docs/ssot/ops.pipeline.md)。

| Workflow | 职责 | 核心价值 |
| :--- | :--- | :--- |
| `terraform-plan.yml` | CI 静态检查 + 看板骨架创建 | 每个 Commit 独立的 **SSOT 仪表盘** |
| `infra-flash-update.yml` | Atlantis 结果搬运 | Plan/Apply 输出实时同步至看板 |
| `claude-code-review.yml` | **AI 自动化审计** | Apply 成功后自动执行代码规范与文档一致性检查 |
| `infra-commands.yml` | 指令分发器 (`dig`, `help`) | 通过评论手动触发环境健康探测，结果回写看板 |
| `deploy-k3s.yml` | 全量灾备 Flash | 灾备与初始引导 (Bootstrap) |

---
*Last updated: 2025-12-19*
