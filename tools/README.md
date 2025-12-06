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
*(Future home for dev scripts, e.g., setup, verify)*

---

## Why is this separate?
- `terraform/` defines **WHAT** we build.
- `tools/` defines **HOW** we build/manage it.
