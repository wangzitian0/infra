# CI/CD Workflows & Design

This directory contains the GitHub Actions workflows that drive the Infrastructure as Code (IaC) pipeline for the `infra` project.

## Design Philosophy

The CI/CD design follows a **GitOps** model with a **Layered Single Source of Truth (SSOT)**.

### 1. Sources of Truth
1.  **Code (Git)**: The desired state of the infrastructure is defined in `terraform/` files.
2.  **State (Cloudflare R2)**: The actual state of the resources is stored in remote Terraform state files locked in R2.
3.  **Reality (K3s/VPS)**: The running infrastructure.

### 2. Workflow Lifecycle

We support two complementary workflows to ensure consistency and rapid iteration:

#### A. PR-Driven Workflow (Atlantis) - *Current Preferred*
This workflow ensures that changes are validated and applied **before** they are merged into `main`. This guarantees that `main` always represents a deployable state.

1.  **Develop**: Create a feature branch and modify Terraform files.
2.  **Plan**: Open a Pull Request (PR).
    *   **Atlantis** detects changes and comments with a `terraform plan`.
    *   GitHub Actions (`terraform-plan.yml`) also runs a validation plan as a second check.
3.  **Review**: Team reviews the code and the plan output.
4.  **Apply**: Comment `atlantis apply` in the PR.
    *   Atlantis applies the changes to the environment (Production/Staging).
    *   The state file is updated in R2.
5.  **Merge**: Once applied and verified, the PR is merged into `main`.

#### B. Convergence Workflow (CD) - *Drift Detection & Safety Net*
This workflow ensures that the `main` branch is always consistent with the live environment, catching any drift or missed applies.

1.  **Merge**: Code triggers `deploy-k3s.yml` on push to `main`.
2.  **Apply**: Terraform runs `apply -auto-approve`.
    *   If Atlantis already applied the changes (Workflow A), this step is a "no-op" (0 changes).
    *   If Atlantis was skipped, this step applies the changes immediately.

---

## Workflow Details

| Workflow | Trigger | Description | Consistency Mechanism |
| :--- | :--- | :--- | :--- |
| **Deploy K3s** (`deploy-k3s.yml`) | `push: [main]` | **The Enforcer**. Applies `terraform/` to production. Bootstraps K3s, deploys Helm charts. | **SSOT Convergence**. Ensures `main` = `Live State`. Uses state locking. |
| **Terraform Plan** (`terraform-plan.yml`) | `pull_request` | **The Validator**. Runs static analysis (`terraform fmt`, `tflint`), **pre-flight URL check**, then `terraform plan` on PRs. **Triggers Atlantis** via comment on success. Shows available commands. | **Dry Run** + **Atlantis Trigger**. |
| **Atlantis** (Self-Hosted) | `issue_comment` | **The Operator**. Runs inside the cluster. Uses **GitHub App** (`infra-flash`) for bot auth. Autoplan disabled. | **Locking**. Locks the directory during plan/apply to prevent conflicts. |
| **Claude** (`claude.yml`) | `/review`, `@claude`, `PTAL`, `infra-flash[bot]` Atlantis success comment | **The Reviewer**. AI code review via Claude. Checks structure, doc consistency, and SSOT. Includes Documentation Guard. Auto-triggered when Atlantis (infra-flash[bot]) reports a successful plan (after `terraform-plan.yml` kicks Atlantis). | **Quality Gate**. Runs after CI + successful Atlantis plan. |

## Handling Multi-Environment & Modules

The project uses a **Layered Architecture** within a single Repository (Monorepo-style logic):

*   **Layer 1 (NoDep)**: Bootstrap (VPS, K3s, Atlantis, DNS/Cert).
*   **Layer 2 (Platform)**: Secrets (Infisical), K8s Dashboard, Kubero.
*   **Layer 3 (Data)**: Business databases (Postgres, Redis, Neo4j).
*   **Layer 4 (Insight)**: Observability (SigNoz), Analytics (PostHog).

### Consistency Strategy
1.  **State Locking**: Terraform Backend (R2) locks state files during any write operation.
2.  **Sequential Apply**: `deploy-k3s.yml` applies layers in order (`-target=module.nodep` first, then full apply).
3.  **Immutable Idempotency**: Terraform ensures that re-running `apply` on the same code results in no changes (idempotency).

## Revert Strategy

If a bad change is deployed:
1.  **Revert PR**: Create a revert commit in Git (`git revert <commit-id>`).
2.  **Plan**: Atlantis shows that resources will be destroyed/modified to match the old state.
3.  **Apply**: `atlantis apply` executes the revert.
4.  **Merge**: The revert is merged, restoring the codebase to the stable state.

> **Note**: Because we rely on Terraform State, "Reverting" code in Git implies "Rolling forward" the state to the previous configuration. This is safer than manual resource deletion.

---

## Claude Code Review

`claude.yml` integrates [Claude Code Action](https://github.com/anthropics/claude-code-action) for AI-powered code review.

### Setup

**One-click (Recommended)**
```bash
claude
/install-github-app
```

This installs the Claude GitHub App and configures `CLAUDE_CODE_OAUTH_TOKEN` automatically.

### Trigger Flow

```
PR opened/updated
    ↓
terraform-plan.yml (CI validation: fmt, tflint, plan)
    ↓ (on CI success)
github-actions comments "atlantis plan"
    ↓
Atlantis runs terraform plan
    ↓ (on plan success)
infra-flash[bot] comments "Ran Plan for X projects..."
    ↓
claude.yml detects bot's success comment
    ↓
Claude review runs
```

Auto-review fires whenever `infra-flash[bot]` posts a successful Atlantis plan comment (CI-triggered or manual re-runs).

### Manual Triggers

| Command | Use Case |
| :--- | :--- |
| `/review` | Request full code review |
| `@claude <question>` | Ask Claude a question |
| `PTAL` | Same as `/review` (Please Take A Look) |

### What It Reviews

**Primary (Project-Specific)**:
- **Structure**: Correct layer (L1-nodep/L2-platform/L3-data/L4-insight), clean module boundaries
- **Code-Doc Consistency**: README.md updated, `0.check_now.md` reflects current work
- **SSOT Compliance**: No duplicate config, proper secrets handling
- **Terraform**: `terraform fmt` compliant, proper resource naming

**Secondary (General)**:
- Code quality and best practices
- Potential bugs or security concerns
- Performance considerations
