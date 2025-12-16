# 禁令
- 永远不要自动修改本文件：除非明确指定，否则AI 不可以自动修改本文件。
- AI 不可以自动合并 PR。

# 原则
- 本地/CI 命令与变量一致，plan 输出一致，资源状态一致
- 当 AI 认为完工，应逐项检查本文件要求后再宣布完成。
- `0.check_now.md`（根）：5W1H 待办 + 验证清单。如果不能用清晰的六段式讲清楚 action，说明干了太多事。
- 设计：简化、正交；开源、自托管、单人强控、可扩展
- 当你想改一个文件的时候，需要首先阅读对应目录的 README.md。
- 提交前的最后一步，需要修改和阅读**所有**改动文件对应目录的 README.md。改文件不改 readme，会让 CI 通不过。

# SSOT Architecture

For a detailed map of where everything lives, refer to:
👉 **[Directory Map (docs/dir.md)](docs/dir.md)**

Core Principle: **Infrastructure as Code (IaC) is the Truth.**

## Module Quick Reference (L1-L4)

| Layer | Directory (Docs) | Responsibility |
|---|---|---|
| **L0 Root** | [`0.tools`](0.tools/README.md) / [`docs`](docs/README.md) | Scripts, CI Automation, Documentation |
| **L1 Bootstrap** | [`1.bootstrap`](1.bootstrap/README.md) | Raw VPS provisioning, k3s installation, DNS/Cert, Atlantis |
| **L2 Platform** | [`2.platform`](2.platform/README.md) | Secrets (Vault), K8s Dashboard, Casdoor |
| **L3 Data** | [`3.data`](3.data/README.md) | Business DBs (Postgres, Redis, Neo4j, ClickHouse) |
| **L4 Apps** | [`4.apps`](4.apps/README.md) | Applications (prod/staging) |

# Standard Operating Procedure (SOP)

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
- **Backend**: Cloudflare R2 (S3-compatible). Defined in `1.bootstrap/backend.tf`.
- **Secrets Strategy**:
    - **L0/L1 (Bootstrap)**: Local Env Vars / GitHub Secrets (`VPS_SSH_KEY`, `R2_*`).
    - **L2+ (Runtime)**: Vault (deployed in L2).
- **Prohibited**:
    - NEVER commit `*.tfvars`, `*.pem`, `*.key`.
    - NEVER hardcode secrets in `.tf` (use `random_password` or vars).

# Documentation Responsibilities (Where to write?)

| Type | Location | Description |
|---|---|---|
| **DONE (History)** | `docs/change_log/` | What was finished. (Symlinked by `0.check_now.md`) |
| **TODO (Plan)** | `project/README.md` | **Mandatory** for all incomplete work/plans. |
| **TRUTH (SSOT)** | `{1.bootstrap,2.platform,3.data,4.apps}/README.md` | Implementation details, Architecture, Usage. |
| **Concepts** | `docs/README.md` | Abstract design decisions only. |
