# GitHub Automation
- **swap**: the README.md and .github/README.md change the position.
- the .github/README.md is the project level single source of truth

CI/CD and bot configuration live here. Workflows under `workflows/` drive Terraform checks and other automation.

## Workflows Overview

| Workflow | Purpose |
| :--- | :--- |
| `terraform-plan.yml` | Validates Terraform and posts per-commit infra-flash status; Atlantis autoplan runs plan on PR updates |
| `deploy-k3s.yml` | Deploys infrastructure on push to main |
| `docs-guard.yml` | Enforces `0.check_now.md` and README updates |
| `claude.yml` | AI code review via Claude GitHub App (auto after Atlantis success comment, or manual `/review`/`@claude`/`PTAL`) |

Documentation guard enforces updating `0.check_now.md` and directory `README.md` files whenever code changes land.

Per-commit infra-flash 评论流（CI → (autoplan) Plan/Apply 追加）见 `docs/ssot/pipeline.md`。

For detailed CI/CD design philosophy, plan/apply/revert workflows, see [workflows/README.md](./workflows/README.md).

---
*Last updated: 2025-12-15*
