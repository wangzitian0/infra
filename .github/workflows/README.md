# Workflows

GitHub Actions entrypoints. Keep setup logic shared (e.g., Terraform init/plan/apply) consistent across workflows and align with `AGENTS.md` instructions.

## Inventory
- `deploy-k3s.yml`: Plans/applies Terraform to deploy k3s to the target VPS.
- `terraform-plan.yml`: Runs Terraform plan on PRs touching IaC files.
- `docs-guard.yml`: Fails PRs that do not update `0.check_now.md` and the relevant `README.md` in each changed directory.
