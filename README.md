# codex_infra

单 VPS、自托管的基础设施仓库（Terraform + k3s + Atlantis），按 L0–L4 分层组织。

## Start Here

- AI 入口：[`AGENTS.md`](./AGENTS.md)
- 当前上下文：[`0.check_now.md`](./0.check_now.md)
- 文档站点（MkDocs）：[`mkdocs.yml`](./website/mkdocs.yml)（仅使用 git 管控的 `*.md`；CI: [`.github/workflows/docs-site.yml`](./.github/workflows/docs-site.yml)）
- 目录结构 SSOT（入口）：[`docs/dir.md`](./docs/dir.md)（权威内容在 `docs/ssot/core.dir.md`）
- 话题 SSOT 索引：[`docs/ssot/README.md`](./docs/ssot/README.md)
- Layer 文档：[`0.tools/README.md`](./0.tools/README.md) · [`1.bootstrap/README.md`](./1.bootstrap/README.md) · [`2.platform/README.md`](./2.platform/README.md) · [`3.data/README.md`](./3.data/README.md) · [`4.apps/README.md`](./4.apps/README.md)
- GitHub 自动化入口：[`.github/README.md`](./.github/README.md) · [`.github/workflows/README.md`](./.github/workflows/README.md)

## GitHub Automation（CI/CD）

CI/CD 与 bot 配置位于 `.github/`；Workflows 在 `.github/workflows/`。

| Workflow | Purpose |
| :--- | :--- |
| `terraform-plan.yml` | Static checks + per-commit infra-flash comment; Atlantis autoplan runs plan on PR updates |
| `infra-flash-update.yml` | Appends Atlantis plan/apply results to the matching infra-flash comment |
| `deploy-k3s.yml` | Deploys bootstrap (L1) on push to main |
| `docs-site.yml` | Builds MkDocs site and deploys to GitHub Pages on main |
| `claude.yml` | AI code review via Claude GitHub App (auto after Atlantis success comment, or manual `/review`/`@claude`/`PTAL`) |

Per-commit infra-flash 评论流（CI → (autoplan) Plan/Apply 追加）见 [`docs/ssot/ops.pipeline.md`](./docs/ssot/ops.pipeline.md)。

更完整的 CI/CD 设计与变更流程见 [`.github/workflows/README.md`](./.github/workflows/README.md)。

---
*Last updated: 2025-12-16*
