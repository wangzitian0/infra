# GitHub Workflows

> **Role**: CI/CD Automation Definitions
> **Executor**: GitHub Actions + Digger

This directory contains the workflow definitions that drive the infrastructure pipeline.

## 📚 SSOT References

For the authoritative pipeline architecture and logic, refer to:
> [**Pipeline SSOT**](../../docs/ssot/ops.pipeline.md)

## Workflows

| Workflow | 触发器 | 职责 |
|:---|:---|:---|
| `ci.yml` | PR / Push / Comment / Dispatch | **统一入口**：解析命令、执行 plan/apply/verify |
| `bootstrap-deploy.yml` | Push(main) / Comment / Dispatch | **L1 Bootstrap**：post-merge drift 追平 + 资源导入（Helm secret 定位 namespace） + `/bootstrap plan/apply` + post-apply DNS/HTTPS 校验 |
| `claude.yml` | `@claude` 评论 | AI 编码/审计任务 |
| `docs-site.yml` | `.md` 文件变动 | 文档站构建部署 |
| `e2e-tests.yml` | Push to main / Dispatch | E2E 回归测试 |
| `readme-coverage.yml` | PR / Push | README 覆盖率检查 |
| `ops-drift-fix.yml` | `schedule` | **Maintenance**. Auto-fix drift (e.g., Vault tokens). |

---
*Last updated: 2025-12-25*
