# GitHub Workflows

> **Role**: CI/CD Automation Definitions
> **Executor**: GitHub Actions + Digger

This directory contains the workflow definitions that drive the infrastructure pipeline.

## 📚 SSOT References

For the authoritative pipeline architecture and logic, refer to:
> [**Pipeline SSOT**](../../docs/ssot/ops.pipeline.md)

## Workflows

| File | Trigger | Purpose |
|------|---------|---------|
| `ci.yml` | `pull_request`, `issue_comment`, `push` | **Unified Entrypoint**. Routes commands to Digger or custom jobs. |
| `bootstrap-deploy.yml` | `workflow_dispatch`, `push` | **L1 Bootstrap**. Deploys the Trust Anchor layer. |
| `e2e-tests.yml` | `workflow_dispatch` | **Verification**. Runs E2E regression suite. |
| `readme-coverage.yml` | `pull_request` | **Documentation**. Ensures README coverage. |
| `ops-drift-fix.yml` | `schedule` | **Maintenance**. Auto-fix drift (e.g., Vault tokens). |

---
*Last updated: 2025-12-25*
