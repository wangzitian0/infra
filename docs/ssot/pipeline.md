# Pipeline SSOT

> **现状**：PR CI 做语法检查与 infra-flash；PR 的 plan/apply 由 Atlantis 驱动；`deploy-k3s.yml` 作为 bootstrap/recovery pipeline（包含 apply）。

---

## 1. 整体架构

```
┌─────────────────────────────────────────────────────────────────────────┐
│                            PR 创建/更新                                  │
└──────────────────────────────┬──────────────────────────────────────────┘
                               │
          ┌────────────────────┴────────────────────┐
          │                                         │
          ▼                                         ▼
┌─────────────────────┐                   ┌─────────────────────┐
│   GitHub Actions    │                   │      Atlantis       │
│ (terraform-plan.yml)│                   │    (via webhook)    │
├─────────────────────┤                   ├─────────────────────┤
│ • terraform fmt     │                   │ • terraform plan    │
│ • tflint            │                   │ • terraform apply   │
│ • terraform validate│                   │ • state management  │
├─────────────────────┤                   ├─────────────────────┤
│ 输出: infra-flash   │                   │ 输出: Atlantis      │
│     评论 (per-commit)│                  │       评论 (per project) │
└─────────────────────┘                   └─────────────────────┘
          │                                         │
          ▼                                         ▼
┌─────────────────────┐                   ┌─────────────────────┐
│  GitHub Checks ✓/✗  │                   │  GitHub Checks ✓/✗  │
└─────────────────────┘                   └─────────────────────┘
```

### 为什么分离？

| 组件 | 职责 | 环境 |
|:-----|:-----|:-----|
| **CI** | 语法检查 (fmt/lint/validate) | GitHub Actions Runner |
| **Atlantis** | 真正的 plan/apply | 集群内 Pod（可访问 Vault/K8s） |

**CI 不做 plan** 的原因：
- PR CI 仅做 `init -backend=false` + `validate`（不访问远端 backend / K8s / Vault）
- 真正的 plan/apply 需要访问 Kubernetes API（集群内）
- 真正的 plan/apply 需要访问 Vault（集群内 + SSO Gate）

---

## 2. 流程详解

### 正常流程 (Happy Path)

```
Commit abc1234 push
    │
    └──► CI 完成
              │
              └──► 新建 Comment 1:
                        "CI ✅ | abc1234"
                        │
                        ▼
              Atlantis autoplan 自动触发
                        │
                        ▼
              Atlantis plan 完成
                        │
                        └──► 追加到 Comment 1:
                                  "Plan ✅"
                                  "👉 Next: atlantis apply"
                                  │
                                  ▼
                        人: "atlantis apply"
                                  │
                                  ▼
                        Atlantis apply 完成
                                  │
                                  └──► 追加到 Comment 1:
                                            "Apply ✅"
                                            "👉 Next: Merge PR"
                                            │
                                            ▼
                                      Merge PR
```

### 多 Commit 场景

```
Commit abc1234 push  →  新建 Comment 1
    │
    └──► CI ✅ → (autoplan) Plan ✅ → Apply ❌ (失败)
              │
              ▼
Commit def5678 push  →  新建 Comment 2 (新评论)
    │
    └──► CI ✅ → (autoplan) Plan ✅ → Apply ✅
              │
              └──► "👉 Next: Merge PR"
```

### CI 失败分支

```
PR 创建
    │
    └──► CI: fmt ❌
              │
              └──► infra-flash 评论: "CI Failed"
                        │
                        ▼
                   本地修复
                   terraform fmt -recursive
                        │
                        ▼
                   git push
                        │
                        └──► CI 重新运行
```

### Atlantis Plan 失败分支

```
PR 创建
    │
    ├──► CI: ✅
    │
    └──► Atlantis: plan ❌
              │
              ├──► "403 permission denied"
              │         │
              │         └──► Vault token 过期
              │                   │
              │                   ▼
              │              更新 VAULT_ROOT_TOKEN
              │                   │
              │                   ▼
              │              手动 apply L1
              │              (cd 1.bootstrap && terraform apply)
              │                   │
              │                   └──► 评论 "atlantis plan" 重试（或 push 触发 autoplan）
              │
              ├──► "state lock"
              │         │
              │         └──► "atlantis unlock"
              │
              └──► "provider mismatch"
                        │
                        ▼
                   terraform init -upgrade
                   git add .terraform.lock.hcl
                   git push
```

---

## 3. infra-flash 评论设计

### 每个 commit 一条评论

**设计原则**：
- 每个 commit push 创建**新评论**
- 同一个 commit 的所有操作（CI、plan、apply）追加到**同一条评论**
- 每条评论包含**下一步指引**
- Atlantis workflow 会输出 `infra-flash-commit:xxxxxxx` 标记，供 `infra-flash-update.yml` 精确定位对应 commit 评论

```markdown
<!-- infra-flash-commit:abc1234 -->
## ⚡ Commit `abc1234`

### CI Validate ✅ | 12:30 UTC

| Layer | Format | Lint | Validate |
|:------|:------:|:----:|:--------:|
| L1 Bootstrap | ✅ | ✅ | ✅ |
| L2 Platform | ✅ | ✅ | ✅ |
| L3 Data | ✅ | ⏭️ | ⏭️ |
| L4 Apps | ✅ | ⏭️ | ⏭️ |

---

### Atlantis Plan ✅ | 12:32 UTC

[View full output](#link)

---

### Atlantis Apply ✅ | 12:45 UTC

[View full output](#link)

👉 **Next:** Merge PR ✅
```

### 状态流转

| 事件 | 评论变化 |
|:-----|:---------|
| Commit 1 push | **新建** Comment 1: CI 状态 + "⏳ Atlantis autoplan" |
| Atlantis autoplan | **追加** Plan 状态 + "👉 Next: atlantis apply" |
| `atlantis apply` | **追加** Apply 状态 + "👉 Next: Merge PR" |
| Commit 2 push | **新建** Comment 2: 新 CI 状态 |

### 审计清晰

```
PR #123
├─ Comment 1 (Commit abc1234)
│   ├─ CI ✅
│   ├─ Plan ✅
│   └─ Apply ❌ (failed, fixed in next commit)
│
├─ Comment 2 (Commit def5678)  ← 修复后的 commit
│   ├─ CI ✅
│   ├─ Plan ✅
│   └─ Apply ✅
│       └─ 👉 Next: Merge PR
│
└─ Merged ✅
```

---

## 4. Workflows 清单

| Workflow | 触发 | 作用 |
|:---------|:-----|:-----|
| `terraform-plan.yml` | `pull_request` (paths filter) | CI 语法检查，每个 commit **新建** infra-flash 评论 |
| `infra-flash-update.yml` | Atlantis 评论 | 追加 Atlantis 状态到 infra-flash 评论 |
| `deploy-k3s.yml` | main push (paths filter) / `workflow_dispatch` | Bootstrap/恢复：按顺序 apply L1→L2→L3→L4（部分步骤仅在 push 执行） |
| `dig.yml` | `/dig` 评论 | 服务连通性检查 |
| `claude.yml` | 评论/Review/Issue/Autoplan | AI 代码审查（best-effort） |

---

## 5. Atlantis 配置

### atlantis.yaml

```yaml
version: 3
parallel_plan: true    # 多 PR 并行 plan
parallel_apply: false  # apply 串行避免冲突

projects:
  # L1 由 GitHub Actions 管理，不在 Atlantis
  
  - name: platform       # L2
    dir: 2.platform
    autoplan:
      enabled: true      # PR 更新自动触发 plan

  - name: data-staging   # L3
    dir: 3.data
    workspace: staging
    autoplan:
      enabled: true      # PR 更新自动触发 plan

  - name: data-prod      # L3
    dir: 3.data
    workspace: prod
    autoplan:
      enabled: true      # PR 更新自动触发 plan
```

> **Note**: `autoplan: true` 会在每次 PR 更新（push 新 commit）时自动触发 `atlantis plan`；`atlantis apply` 仍需人工评论触发

---

## 6. 变量一致性

### 变量与密钥来源（事实）

```
1Password (SSOT)
     ↓ op item get + gh secret set
GitHub Secrets
     │
     ├──► PR CI (`terraform-plan.yml`)
     │         └──► 仅需 GitHub App 凭据（发 infra-flash 评论）
     │
     ├──► Deploy (`deploy-k3s.yml`)
     │         └──► 通过 `.github/actions/terraform-setup` 导出 TF_VAR_* + backend init + apply（L1-L4；L3/L4 仅 push）
     │
     └──► Atlantis Pod
               └──► 集群内运行 plan/apply（从 K8s Secret / Vault 获取运行期密钥）
```

### 关键点

- PR CI 不注入业务/基础设施密钥：`terraform validate` 使用 `init -backend=false`，只做语法与静态检查。
- PR CI 写评论使用 GitHub App token（`ATLANTIS_GH_APP_ID/ATLANTIS_GH_APP_KEY`）。
- 真正需要 backend / provider 凭据的是：`deploy-k3s.yml`（apply）与 Atlantis（plan/apply）。

> **TODO（理想态）**
> - CI/Deploy/Atlantis 统一 Terraform 版本，并在关键步骤输出 `terraform version` 做断言。
> - `deploy-k3s.yml` 的“破坏性清理”改为显式开关（`workflow_dispatch` input），默认只做 `terraform import` 或直接失败提示人工处理。
> - L2/L3/L4 的日常变更只通过 Atlantis；`deploy-k3s.yml` 默认只跑 L1 bootstrap（需要全量恢复时再显式开启）。

---

## 7. 故障恢复

### Vault Token 过期

```bash
# 1. 获取新 token
op read 'op://Infrastructure/Vault Root Token/credential'

# 2. 更新 GitHub Secret
gh secret set VAULT_ROOT_TOKEN --body "<token>" --repo wangzitian0/infra

# 3. Apply L1 (更新 Atlantis Pod)
cd 1.bootstrap
terraform apply

# 4. 重试 Atlantis plan
# 在 PR 评论: atlantis plan（或 push 触发 autoplan）
```

### State Lock

```
# PR 评论
atlantis unlock
atlantis plan
```

### Provider 版本不匹配

```bash
terraform init -upgrade
terraform providers lock \
  -platform=linux_amd64 \
  -platform=darwin_amd64 \
  -platform=darwin_arm64
git add .terraform.lock.hcl
git commit -m "chore: update provider lock"
git push
```

---

## 8. 健康检查分层

```
┌─────────────────────────────────────────────────────────────┐
│  时机        │  机制                │  作用                 │
├─────────────────────────────────────────────────────────────┤
│  CI         │  fmt/lint/validate   │  语法正确性           │
│  Plan       │  variable.validation │  拒绝无效输入          │
│  Apply 前   │  precondition        │  验证依赖就绪          │
│  Pod 启动   │  initContainer       │  等待依赖可用          │
│  运行时     │  readiness/liveness  │  流量控制 / 自动重启   │
└─────────────────────────────────────────────────────────────┘
```

---

## 相关文件

| 文件 | 用途 |
|:-----|:-----|
| `.github/workflows/terraform-plan.yml` | CI workflow |
| `atlantis.yaml` | Atlantis 项目配置 |
| `1.bootstrap/2.atlantis.tf` | Atlantis 部署定义 |
| `docs/ssot/secrets.md` | 密钥管理 |
| `docs/ssot/vars.md` | 变量定义 |
