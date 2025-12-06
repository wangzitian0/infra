# 禁令
- 永远不要自动修改本文件：除非明确指定，否则AI 不可以自动修改本文件。

# 原则
- 本地/CI 命令与变量一致，plan 输出一致，资源状态一致
- 当 AI 认为完工，应逐项检查本文件要求后再宣布完成。
- `0.check_now.md`（根）：5W1H 待办 + 验证清单。如果不能用清晰的六段式讲清楚 action，说明干了太多事。
- 设计：简化、正交；开源、自托管、单人强控、可扩展
- 当你想改一个文件的时候，需要首先阅读对应目录的 README.md。
- 当你觉得你修改差不多完成的时候，需要修改和阅读所有改动文件对应目录的 README.md，确保没有遗漏。



# SSOT Architecture

For a detailed map of where everything lives, refer to:
👉 **[Directory Map (docs/dir.md)](docs/dir.md)**

Core Principle: **Infrastructure as Code (IaC) is the Truth.**

## Module Quick Reference (L1-L5)

| Layer | Directory (Docs) | Responsibility |
|---|---|---|
| **L0 Root** | [`terraform`](terraform/README.md) / [`tools`](tools/README.md) | Root Module, Global Vars, CI Automation |
| **L1 Bootstrap** | [`1.nodep`](terraform/1.nodep/README.md) | Raw VPS provisioning, k3s installation |
| **L2 Foundation** | [`2.env_and_networking`](terraform/2.env_and_networking/README.md) | Secrets (Infisical), Ingress Domains, Base DB |
| **L3 Runtime** | [`3.computing`](terraform/3.computing/README.md) | PaaS (Kubero), Dashboard, Workload Controllers |
| **L4 Data** | [`4.storage`](terraform/4.storage/README.md) | Business Logic DBs (Postgres, Redis, Neo4j) |
| **L5 Insight** | [`5.insight`](terraform/5.insight/README.md) | Observability (SigNoz), Analytics (PostHog)# Standard Operating Procedure (SOP)

## 1. Development Workflow
- **Read First**: Before modifying any layer, read its `README.md`.
- **Scope Control**: Focus on single-VPS MVP; avoid over-engineering.
- **Terraform Cycle**:
    1. Modify `.tf` files.
    2. `terraform fmt -check` (Formatting).
    3. `terraform plan` (Preview changes).
    4. Update `README` / `change_log`.
    5. Commit/PR (Triggers CI).

## 2. Security & State
- **Backend**: Cloudflare R2 (S3-compatible). defined in `0.common/backend.tf`.
- **Secrets Strategy**:
    - **L0/L1 (Bootstrap)**: Local Env Vars / GitHub Secrets (`VPS_SSH_KEY`, `R2_*`).
    - **L2+ (Runtime)**: Infisical (deployed in L2).
- **Prohibited**:
    - NEVER commit `*.tfvars`, `*.pem`, `*.key`.
    - NEVER hardcode secrets in `.tf` (use `random_password` or vars).

# Documentation Responsibilities (Where to write?)

| Type | Location | Description |
|---|---|---|
| **DONE (History)** | `docs/change_log/` | What was finished. (Symlinked by `0.check_now.md`) |
| **TODO (Plan)** | `project/README.md` | **Mandatory** for all incomplete work/plans. |
| **TRUTH (SSOT)** | `terraform/*/README.md` | Implementation details, Architecture, Usage. |
| **Concepts** | `docs/README.md` | Abstract design decisions only. |
