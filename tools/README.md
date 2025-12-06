# Tools & CI/CD (Meta Layer)

This directory defines the **Meta / Management Layer** of the infrastructure.
It serves as the Single Source of Truth (SSOT) for *how* we manage operations, CI/CD, and automation.

## 1. CI/CD Orchestration (Terrateam)
- **Config**: [`.terrateam/config.yml`](../.terrateam/config.yml) (Symlinked or referenced)
- **Entrypoint**: [`.github/workflows/terrateam.yml`](../.github/workflows/terrateam.yml)
- **Role**: Handles Terraform `plan` (on PR) and `apply` (via comment). Ensures consistency and locking.

## 2. GitHub Configuration
- **Workflows**: [`.github/workflows`](../.github/workflows)
- **Secrets**: Managed via GitHub Repository Settings.

## 3. Local Scripts
- `./tools/docs-guard.sh <base-ref> [head-ref]`: Run the documentation guard locally; CI calls it to ensure `0.check_now.md` and touched directories' `README.md` files are updated together.
- `./tools/setup_remote_debug.sh`: Setup remote debugging environment for k3s cluster.

---

## Why is this separate?
- `terraform/` defines **WHAT** we build.
- `tools/` defines **HOW** we build/manage it.

## Troubleshooting Terrateam
If `Terrateam Plan` does not appear in PR checks:
1.  **Check App Installation**: Ensure "Terrateam" GitHub App is installed on `wangzitian0/infra`.
2.  **Check Workflow on Main**: Ensure `.github/workflows/terrateam.yml` exists on the `main` branch.
3.  **Check Secrets**: Ensure repository secrets (AWS_*, R2_*, VPS_*) are active.
4.  **Re-Trigger**: Comment `terrateam plan` in the PR.
