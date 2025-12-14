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
| **Terraform Plan** (`terraform-plan.yml`) | `pull_request` | **The Validator**. Runs syntax-only checks (`terraform fmt`, `tflint`, `validate`). Posts **infra-flash** comment with status matrix. **Does NOT run plan** - Atlantis does. | **Syntax Check** + **Status Dashboard**. |
| **Atlantis** (Self-Hosted) | `issue_comment` | **The Operator**. Runs inside the cluster. Uses **GitHub App** (`infra-flash`) for bot auth. **Sole plan/apply authority**. | **Locking**. Locks the directory during plan/apply to prevent conflicts. |
| **Claude** (`claude.yml`) | `/review`, `@claude`, `PTAL`, `infra-flash[bot]` Atlantis success comment | **The Reviewer**. AI code review via Claude. Checks structure, doc consistency, and SSOT. Includes Documentation Guard. Auto-triggered when Atlantis (infra-flash[bot]) reports a successful plan (after `terraform-plan.yml` kicks Atlantis). | **Quality Gate**. Runs after CI + successful Atlantis plan. |
| **Dig** (`dig.yml`) | `/dig` comment on PR | **The Health Checker**. Tests connectivity to all documented services and posts a live-updating table with status. | **Observability**. Quick service status check. |

## infra-flash Comment

The `terraform-plan.yml` workflow posts a single, updateable **infra-flash** comment on each PR:

```
## ⚡ infra-flash | `feature-branch`

### 📍 Commit
`abc1234` - feat: add new feature

### 🔍 CI Status (Syntax Only)

| Layer | Format | Lint | Validate |
|:------|:------:|:----:|:--------:|
| **L1** Bootstrap | ✅ | ✅ | ✅ |
| **L2** Platform | ✅ | ✅ | ✅ |
| **L3** Data | ✅ | ✅ | ✅ |

### 🔮 Atlantis (Real Plan/Apply)

> CI 只检查语法。**Atlantis 是唯一的 plan/apply 入口**。
```

### Why CI Only Validates Syntax

1. **CI runs outside the cluster** - no access to Vault, K8s APIs
2. **Atlantis runs inside the cluster** - has full access to all resources
3. **Plan = Apply consistency** - only one system does both

This architecture ensures that `terraform plan` output always matches what `terraform apply` will do.

---

## Handling Multi-Environment & Modules

The project uses a **Layered Architecture** within a single Repository (Monorepo-style logic):

*   **Layer 1 (NoDep)**: Bootstrap (VPS, K3s, Atlantis, DNS/Cert).
*   **Layer 2 (Platform)**: Secrets (Vault), K8s Dashboard, Kubero.
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

## Atlantis Commands Reference

Comment on a PR to trigger Atlantis operations:

| Command | Description |
|---------|-------------|
| `atlantis plan` | Run plan for all modified directories |
| `atlantis plan -d <dir>` | Run plan for specific directory (e.g., `atlantis plan -d 2.platform`) |
| `atlantis apply` | Apply all pending plans |
| `atlantis apply -d <dir>` | Apply plan for specific directory |
| `atlantis unlock` | Unlock the PR (releases state lock) |

### Advanced Commands

Pass extra Terraform arguments using `--`:

```bash
# Destroy resources in a directory
atlantis plan -d 2.platform -- -destroy
atlantis apply -d 2.platform

# Target specific resources
atlantis plan -d 1.bootstrap -- -target=helm_release.vault

# Refresh state only
atlantis plan -d 2.platform -- -refresh-only
```

> **Reference**: [Atlantis Docs - Using Atlantis](https://www.runatlantis.io/docs/using-atlantis.html)

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
| `/dig` | Run service health check (see below) |

---

## Service Health Check (/dig)

`dig.yml` provides a quick way to check connectivity to all documented services.

### Usage

Comment `/dig` on any PR to trigger a health check. The bot will:

1. Create a comment with "Testing connectivity..."
2. curl all documented services (L1-L4)
3. Update the comment with a results table

### Example Output

```
## Service Health Check :green_circle: All systems operational

<details open>
<summary>Results: 4/10 healthy</summary>

| Layer | Service | Domain | Status |
|-------|---------|--------|--------|
| L1 | Atlantis | `i-atlantis.${BASE_DOMAIN}` | :lock: 401 Auth Required |
| L2 | K8s Dashboard | `i-kdashboard.${BASE_DOMAIN}` | :white_check_mark: 200 OK |
| L2 | Vault | `i-secrets.${BASE_DOMAIN}` | :x: 502 Bad Gateway |
| ... | ... | ... | ... |

</details>
```

### Required Secrets

| Secret | Description |
| :--- | :--- |
| `BASE_DOMAIN` | Base domain for all services (e.g., `example.com`) |

### Status Legend

| Emoji | Meaning |
| :--- | :--- |
| :white_check_mark: | 200 OK - Service healthy |
| :lock: | 401/403 - Auth required (expected for protected services) |
| :grey_question: | 404 - No backend configured |
| :warning: | 503/526 - Service unavailable or SSL error |
| :x: | 502/504 - Backend error |
| :no_entry: | Timeout - Service unreachable |

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
