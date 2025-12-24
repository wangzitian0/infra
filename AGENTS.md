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
- atlantis的存在，当你要检查一个 PR 的状态时，需要检查 atlantis / infra-flash 的评论。
- 请你使用渐进式提交的方式，每一步都有 日志可以校验你的设想和实现是对的的。不损坏线上的前提下，阶段性成果可以提前交代码库。

# 问题解决框架
当你拿到一个问题，请使用 STAR framework 来分析问题。
- Situation：问题背景，问题现象，问题影响。
- Task：问题的高优先级目标。
- Action：解决高优先级目标的步骤拆解。
- Result：问题的解决结果，回到 situation，告诉我你有多少%的信心了。

# SSOT Architecture

For a detailed map of where everything lives, refer to:
👉 **[Directory Map (docs/ssot/core.dir.md)](docs/ssot/core.dir.md)**

Core Principle: **Infrastructure as Code (IaC) is the Truth.**

## Module Quick Reference

| Module | Directory (Docs) | Responsibility |
|---|---|---|
| **Root** | [`tools`](tools/README.md) / [`docs`](docs/README.md) | Scripts, CI Automation, Documentation |
| **Bootstrap** | [`bootstrap`](bootstrap/README.md) | Raw VPS provisioning, k3s installation, DNS/Cert, Atlantis |
| **Platform** | [`platform`](platform/README.md) | Control Plane (Vault, SSO, PaaS, Observability) |
| **Data** | [`envs/{env}/data`](envs/README.md) | Business DBs (Postgres, Redis, ClickHouse, etc.) |

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
- **Backend**: Cloudflare R2 (S3-compatible). Defined in `bootstrap/backend.tf`.
- **Secrets Strategy**:
    - **Bootstrap**: Local Env Vars / GitHub Secrets (`VPS_SSH_KEY`, `R2_*`).
    - **Platform+ (Runtime)**: Vault (deployed in Platform layer).
- **Prohibited**:
    - NEVER commit `*.tfvars`, `*.pem`, `*.key`.
    - NEVER hardcode secrets in `.tf` (use `random_password` or vars).

## 3. Secret & Variable Pipeline (The Variable Chain)
- **Variable Changes**: When adding/changing a variable in any `variables.tf`, you MUST update the mapping in `tools/ci_load_secrets.py`. CI will fail if they are not aligned (Variable Guard).
- **1Password Alignment**: 
    - 1Password is the master SSOT. GitHub Secrets are just a cache.
    - NEVER manually set secrets in GitHub Web UI.
    - ALWAYS use `python3 tools/sync_secrets.py` to push secrets from 1Password to GitHub.
- **Composite Action Constraint**: Inside a GitHub Composite Action (`action.yml`), NEVER use `env: ${{ env.VAR }}` to map variables generated in previous steps of the same action. Use raw shell variables `$VAR` instead to avoid shadowing.

## 4. Defensive Maintenance SOP (Infrastructure Reliability)
- **Rule 1: No Blackbox Parameters**. Before using a new resource or provider argument, you MUST read the `versions.tf` and verify the exact argument name from the Official Terraform Registry. Never assume common names like `timeout` or `retry`.
- **Rule 2: Whitebox Logic**. Any dynamic string construction (URLs, IDs, Paths) MUST be verifiable. Use `terraform_data` or `output` to echo the final constructed string in Plan output.
- **Rule 3: Drift Detection First**. For external API resources (Casdoor, Vault), always prefer `data` sources with `precondition` to detect "already exists" errors during the **Plan** stage, not Apply.
- **Rule 4: State Discrepancy Protocol**. If an Apply fails with a conflict (e.g., 500 Already Exists), DO NOT blindly re-run. You MUST:
    1. Query the live API/DB to confirm the resource status.
    2. Synchronize state via `terraform import` or manual cleanup of ghost resources.
    3. Scale down cached services (like Casdoor) if necessary to clear memory drift.
- **Rule 5: Cooldown for Ingress/DNS**. When deploying Ingress, Certs, or DNS records, always include a `time_sleep` resource (minimum 60s) before any Health Check data source to account for propagation delay.

## 4. Defensive Maintenance SOP (Infrastructure Reliability)
- **Rule 1: No Blackbox Parameters**. Before using a new resource or provider argument, you MUST read the `versions.tf` and verify the exact argument name from the Official Terraform Registry. Never assume common names like `timeout` or `retry`.
- **Rule 2: Whitebox Logic**. Any dynamic string construction (URLs, IDs, Paths) MUST be verifiable. Use `terraform_data` or `output` to echo the final constructed string in Plan output.
- **Rule 3: Drift Detection First**. For external API resources (Casdoor, Vault), always prefer `import` blocks or `data` sources with `precondition` to detect "already exists" errors during the **Plan** stage, not Apply.
- **Rule 4: State Discrepancy Protocol**. If an Apply fails with a conflict (e.g., 500 Already Exists), DO NOT blindly re-run. You MUST:
    1. Query the live API/DB to confirm the resource status.
    2. Synchronize state via `terraform import` or manual cleanup of ghost resources.
    3. Scale down cached services (like Casdoor) if necessary to clear memory drift.

## 5. Managed Resource Evaluation SOP (Provider Priority)
- **优先级**：原生/官方 Provider > 合作/活跃社区 Provider > REST API Provider > `null_resource` > `local-exec`。
- **评估清单**：
    1. 是否支持 Read/Import/Plan diff；若缺失，必须补 `data` + `precondition`/`terraform_data` 白盒化。
    2. 版本是否锁定（`.terraform.lock.hcl`）且参数来自 Registry。
- **降级条件**：仅在上层 Provider 缺功能或阻断 bug 时允许，原因写入 `docs/project/README.md`（未完成）或 `docs/change_log/`（已完成）。
- **落地要求**：`null_resource`/`local-exec` 必须幂等、带明确 `triggers`、输出可验证，并标注替换计划。

# Documentation Responsibilities (Where to write?)

| **DONE (History)** | `docs/change_log/` | What was finished. (Symlinked by `0.check_now.md`) |
| **TODO (Plan)** | `docs/project/README.md` | **Mandatory** for all incomplete work/plans. |
| **TRUTH (SSOT)** | `{bootstrap,platform,envs/**/data}/README.md` | Implementation details, Architecture, Usage. |
| **Concepts** | `docs/README.md` | Abstract design decisions only. |
