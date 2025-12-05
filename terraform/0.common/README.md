# 0.common (Global Configuration / Orchestrator)

**Scope**:
- Root execution entry point (`main.tf`).
- Environment variables (`envs/*.tfvars`).
- **CI/CD Workflows & Policies**.

## Architecture & SSOT
This directory acts as the "Brain" of the infrastructure.
- **State**: Backend configuration (R2).
- **Inputs**: All variable definitions merge here.

## CI/CD Strategy (from CI-MERGE-STRATEGY & TODO)

### 1. Workflow Goals
1. **Status Checks**: Block merge if CI/Plan fails.
2. **Comment-Driven**: `atlantis apply` (future) or Comment ops.
3. **Environment Consistency**:
   - `dev` ≈ `ci` (Local/CI consistency)
   - `staging` ≈ `prod` (Data/Architecture parity)

### 2. Branch Protection
- **Target**: `main`
- **Requirements**:
  - `Require status checks to pass` (Terraform Plan).
  - `Require branches to be up to date`.
  - `Dismiss stale approvals`.

### 3. Usage Guide
**Local Apply (Staging)**:
```bash
terraform init -backend-config="key=staging.tfstate"
terraform apply -var-file="envs/staging.tfvars"
```

**CI Pipeline**:
- **Pull Request**: Runs `terraform plan`.
- **Merge to Main**: Runs `terraform apply` (staging).
- **Artifacts**: Stores `kubeconfig` for verification.
