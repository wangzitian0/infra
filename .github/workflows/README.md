# GitHub Actions Workflows

## 架构概览

```
PR 创建/更新
     │
     ├──► terraform-plan.yml (CI)     ──► infra-flash 评论
     │    fmt/lint/validate
     │
     └──► Atlantis (webhook)          ──► Atlantis 评论
          terraform plan/apply
```

**分工**：
- **CI**: 语法检查（fmt/lint/validate）
- **Atlantis**: 真正的 plan/apply（集群内运行，可访问 Vault/K8s）

---

## Workflows

| Workflow | 触发 | 用途 |
|:---------|:-----|:-----|
| [`terraform-plan.yml`](#terraform-ci) | `pull_request` (paths filter) | CI 语法检查，为每个 commit 新建 infra-flash 评论 |
| [`infra-flash-update.yml`](#infra-flash-update) | Atlantis 评论 | 追加 Atlantis 状态到 infra-flash 评论 |
| [`deploy-k3s.yml`](#deploy-k3s) | main push (paths filter) / 手动 | Bootstrap/恢复：按顺序 apply L1→L2→L3→L4（部分步骤仅在 push 执行） |
| [`dig.yml`](#health-check) | `/dig` 评论 | 服务连通性检查 |
| [`docs-site.yml`](#docs-site) | PR / main push / 手动 | 构建 MkDocs 文档站点；main 自动部署到 GitHub Pages |
| [`readme-coverage.yml`](#readme-coverage) | PR / main push | README 更新覆盖率检查（≥80%） |
| [`claude.yml`](#claude-review) | 评论/Review/Issue/Autoplan | AI 代码审查（best-effort） |

---

## terraform-plan.yml {#terraform-ci}

**触发**: PR 修改 `1.bootstrap/`, `2.platform/`, `3.data/`, `4.apps/` 或 `.github/workflows/`

### 执行步骤

1. `terraform fmt -check -recursive -diff` - 格式检查
2. `tflint` - Lint 检查 (L1/L2/L3/L4)
3. `terraform validate` - 语法验证 (L1/L2/L3/L4, `init -backend=false`)
4. **发布 infra-flash 评论**：每个 commit push 新建一条评论，记录 CI 结果和下一步指引

> CI 里调用 `hashicorp/setup-terraform@v3` 时将 `terraform_wrapper: false`，避免 wrapper 把 `terraform state show` 这类“资源不存在 → exit code 1”的场景上抛成 workflow error，确保 Bash 的 `if ! ...; then ...` 能按预期处理退出码。

### infra-flash 评论（Per-Commit）

**流程**：
1. **骨架创建**：CI 开始时立即创建评论，锁定 commit
2. **CI 结果更新**：检查完成后更新评论（通过=简洁，失败=详细表格）
3. **Atlantis Autoplan**：Atlantis 并行自动运行 plan
4. **追加 Plan/Apply**：`infra-flash-update.yml` 捕捉 Atlantis 评论并追加到 infra-flash 评论

**评论结构**：

```markdown
<!-- infra-flash-commit:abc1234 -->
## ⚡ Commit `abc1234`

<details><summary>📖 Commands</summary>
| Command | Description |
| `atlantis plan` | Re-run plan |
| `atlantis apply` | Apply changes |
| `atlantis unlock` | Unlock PR |
</details>

---

### CI Validate ✅ | [abc1234](ci-run-link) | 12:30 UTC

---

### Atlantis Actions

| Action | Trigger | Status | Output | Time |
|:-------|:--------|:------:|:-------|:-----|
| Plan | [@autoplan #12345](atlantis-comment-link) | ✅ | [output](link) | 12:31 UTC |
| Apply | [@user #67890](link) | ✅ | [output](link) | 12:35 UTC |

---

✅ **Ready to merge!**
```

**Trigger 格式**：
- `[@autoplan #comment-id](link)` - Atlantis 自动运行
- `[@username #comment-id](link)` - 人类评论手动触发

### Atlantis（Autoplan）

本仓库 `atlantis.yaml` 开启了 `autoplan.enabled=true`。每次 push 都会触发 Atlantis 自动 plan。

- CI 和 Atlantis 并行运行
- Race condition 解决：`infra-flash-update.yml` 会等待或重试，直到找到对应 commit 的 infra-flash 评论（骨架已由 CI 率先创建）
- 即使 Atlantis 先完成，只要骨架评论已存在，状态就能追加进去


---

## infra-flash-update.yml {#infra-flash-update}

**触发**: Atlantis (`infra-flash[bot]`) 发布评论

监听 Atlantis 的 plan/apply 评论，追加状态到**当前 commit**的 infra-flash 评论：

```
Atlantis 评论 "Ran Plan for..."
    │
    └──► infra-flash-update.yml
              │
              └──► 追加到 infra-flash 评论:
                        "### Atlantis Plan ✅ | 12:32 UTC"
```

- 通过 `<!-- infra-flash-commit:abc1234 -->` 锚点定位评论
- 自动附带触发者评论 & Atlantis 输出链接
- 成功时追加下一步（Plan → Apply → Merge），失败则指向修复操作
- **重要**：通过 Atlantis 输出的 `infra-flash-commit:xxxxxxx` 标记定位对应 commit 评论（使用 `targetSha` 而非 PR HEAD，支持 plan 运行时有新 commit push 的场景）
- 权限：需要 `issues: write`（更新评论）与 `pull-requests: write`（读取 PR 信息）
- 兼容性：使用 `"on":` 而不是 `on:`，避免 YAML 解析把 `on` 误判为布尔值导致 workflow 无法触发

---

## deploy-k3s.yml {#deploy-k3s}

**触发**: `push` to `main` 或 `workflow_dispatch` (手动)

用于 bootstrap/恢复：按顺序 apply L1→L2→L3→L4（当前 L3/L4 的 apply/verify 仅在 `push` 事件执行；`workflow_dispatch` 会跳过这些 step）。

一致性策略：
- workflow 会尝试 `terraform import` 把已存在的资源纳入 state 管理（例如 `helm_release.atlantis`）。
- 为修复 Helm `cannot re-use a name` 这类“集群残留但 state 缺失”的冲突，当前会清理 `platform` 命名空间下 Atlantis 的 Helm release secrets（按 `sh.helm.release.v1.atlantis*` 模式匹配），并删除相关 `deployment/svc/statefulset`（见 `Import Existing Resources` step）。

> **TODO（理想态）**
> - 默认不做任何自动删除；需要清理时改为显式开关（`workflow_dispatch` input）+ 输出将删除的资源清单供人工确认。
> - L2/L3/L4 的日常变更只通过 Atlantis；`deploy-k3s.yml` 默认只跑 L1 bootstrap（需要全量恢复时再显式开启）。

---

## dig.yml {#health-check}

**触发**: PR 评论 `/dig`

检查所有服务的连通性：

```markdown
## Service Health Check 🟢

| Layer | Service | Status |
|-------|---------|--------|
| L1 | Atlantis | 🔒 401 |
| L2 | Vault | ✅ 200 |
| L2 | Dashboard | ✅ 200 |
```

---

## claude.yml {#claude-review}

**触发**: 多事件触发（见 `.github/workflows/claude.yml`），包括：
- PR/Review/Issue 评论：`/review`、`@claude`、`PTAL`（非 Bot）
- Atlantis plan 成功后的 `infra-flash[bot]` 评论（自动触发）
- `issues` / `pull_request_review` 等事件（包含 `@claude` 时）

AI 代码审查：
- 检查 Terraform 结构
- 验证 SSOT 一致性
- 识别潜在问题
- 可靠性：该 workflow 为 best-effort（`continue-on-error: true`），失败不会阻塞主流水线

---

## docs-site.yml {#docs-site}

**触发**: PR / `push` to `main` (paths filter) / `workflow_dispatch`

用途：
- 构建静态文档站点（`mkdocs.yml`；`docs_dir: mkdocs`）
- 文档来源：`mkdocs_gen_repo_pages.py` 仅从 git 管控的 `*.md` 生成 `repo/` 页面（含 submodule）
- 注意：新增文档需先 `git add`（生成脚本基于 `git ls-files`）
- `main` 分支 push 自动部署到 GitHub Pages（GitHub Actions → Pages）

本地运行：

```bash
python3.12 -m venv .venv  # 或 python3.11
.venv/bin/python -m pip install -r requirements-mkdocs.txt
git submodule update --init --recursive  # 如果需要 apps 文档
.venv/bin/mkdocs serve
```

## readme-coverage.yml {#readme-coverage}

**触发**: PR / `push` to `main`

用途：
- 约束目录变更时的 README 同步更新（默认阈值 ≥80%）
- 与本地脚本同源：`scripts/check-readme-coverage.sh`

本地运行：

```bash
BASE_REF=origin/main scripts/check-readme-coverage.sh
```

## Atlantis 命令

| 命令 | 用途 |
|:-----|:-----|
| `atlantis plan` | 手动触发 plan |
| `atlantis plan -d 2.platform` | 指定目录 plan |
| `atlantis apply` | 应用所有 plan |
| `atlantis apply -d 2.platform` | 指定目录 apply |
| `atlantis unlock` | 解锁 project |

### 高级用法

```bash
# 销毁资源
atlantis plan -d 2.platform -- -destroy
atlantis apply -d 2.platform

# 指定 target
atlantis plan -d 1.bootstrap -- -target=helm_release.vault

# 刷新 state
atlantis plan -d 2.platform -- -refresh-only
```

---

## 故障排除

### CI 失败

```bash
# 本地修复
terraform fmt -recursive
terraform validate
git push
```

### Atlantis Plan 失败

| 错误 | 解决方案 |
|:-----|:---------|
| `403 permission denied` | Vault token 过期 → 更新 `VAULT_ROOT_TOKEN`，apply L1 |
| `state lock` | `atlantis unlock` |
| `provider mismatch` | `terraform init -upgrade`，提交 lock 文件 |

### 更新 Vault Token

```bash
# 1. 更新 GitHub Secret
gh secret set VAULT_ROOT_TOKEN --body "<new-token>" --repo wangzitian0/infra

# 2. Apply L1 更新 Atlantis Pod
cd 1.bootstrap && terraform apply

# 3. 重试
# PR 评论: atlantis plan
```

---

## 相关文档

- [ops.pipeline.md](../../docs/ssot/ops.pipeline.md) - 完整流程设计
- [platform.secrets.md](../../docs/ssot/platform.secrets.md) - 密钥管理
- [Atlantis Docs](https://www.runatlantis.io/docs/using-atlantis.html)
