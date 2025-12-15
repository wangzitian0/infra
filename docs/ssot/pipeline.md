# Pipeline SSOT

> **核心原则**：CI 做语法检查，Atlantis 做 Plan/Apply

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
│   (terraform-ci)    │                   │    (via webhook)    │
├─────────────────────┤                   ├─────────────────────┤
│ • terraform fmt     │                   │ • terraform plan    │
│ • terraform lint    │                   │ • terraform apply   │
│ • terraform validate│                   │ • state management  │
├─────────────────────┤                   ├─────────────────────┤
│ 输出: infra-flash   │                   │ 输出: Atlantis      │
│       评论 (单条)   │                   │       评论 (per project) │
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

**CI 无法做 plan** 的原因：
- 无法访问 Kubernetes API（集群内）
- 无法访问 Vault（集群内 + SSO Gate）
- Provider 初始化会失败

---

## 2. 流程详解

### 正常流程 (Happy Path)

```
Commit abc1234 push
    │
    └──► CI 完成
              │
              └──► infra-flash 评论:
                        "CI ✅ | abc1234"
                        "👉 Comment `atlantis plan` to run"
                        │
                        ▼
              人: "atlantis plan"  ← 手动触发
                        │
                        ▼
              Atlantis plan 完成
                        │
                        └──► infra-flash 评论追加:
                                  "Atlantis Plan ✅"
                                  │
                                  ▼
                            Review plan
                                  │
                                  ▼
                        人: "atlantis apply"
                                  │
                                  ▼
                        Atlantis apply 完成
                                  │
                                  └──► infra-flash 评论追加:
                                            "Atlantis Apply ✅"
                                            │
                                            ▼
                                      Merge PR
```

### 新 Commit 时

```
Commit def5678 push (新 commit)
    │
    └──► infra-flash 评论重置:
              "CI ✅ | def5678"                    ← 新 commit
              "👉 Comment atlantis plan to run"   ← 清除旧 plan 状态
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
              │                   └──► "atlantis plan" 重试
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

### 单条评论，per-commit 追踪

每个 PR **一条评论**，随流程**追加更新**：

```markdown
<!-- infra-flash-ci -->
<!-- commit:abc1234 -->
## ⚡ infra-flash | `abc1234`

### CI Validate ✅ | 12:30 UTC

| Layer | Format | Lint | Validate |
|:------|:------:|:----:|:--------:|
| L1 Bootstrap | ✅ | ✅ | ✅ |
| L2 Platform | ✅ | ✅ | ✅ |
| L3 Data | ✅ | ⏭️ | ⏭️ |

---

### Atlantis Plan ✅ | 12:32 UTC

[View full output](#link)

---

### Atlantis Apply ✅ | 12:45 UTC

[View full output](#link)
```

### 状态流转

| 事件 | 评论变化 |
|:-----|:---------|
| CI 完成 | 更新 CI 状态，显示 "⏳ Waiting for Atlantis..." |
| 人: `atlantis plan` | (等待 Atlantis 执行) |
| Atlantis plan 完成 | 追加 Plan 状态 |
| 人: `atlantis apply` | (等待 Atlantis 执行) |
| Atlantis apply 完成 | 追加 Apply 状态 |
| 新 commit push | **重置**：新 CI 状态，清除旧 Atlantis 状态 |

### CI 失败时

```markdown
## ⚡ infra-flash | `abc1234`

### CI Validate ❌ | 12:30 UTC

| Layer | Format | Lint | Validate |
|:------|:------:|:----:|:--------:|
| L1 Bootstrap | ❌ | ⏭️ | ⏭️ |

```bash
# Fix locally:
terraform fmt -recursive
terraform validate
git push
```
```

---

## 4. Workflows 清单

| Workflow | 触发 | 作用 |
|:---------|:-----|:-----|
| `terraform-plan.yml` | PR push | CI 语法检查，创建/更新 infra-flash 评论 |
| `infra-flash-update.yml` | Atlantis 评论 | 追加 Atlantis 状态到 infra-flash 评论 |
| `deploy-k3s.yml` | 手动 | 初始 K3s 集群部署 |
| `dig.yml` | `/dig` 评论 | 服务连通性检查 |
| `claude.yml` | `/review` 评论 | AI 代码审查 |

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
      enabled: false     # 手动触发: atlantis plan -p platform

  - name: data-staging   # L3
    dir: 3.data
    workspace: staging
    autoplan:
      enabled: false     # 手动触发: atlantis plan -p data-staging

  - name: data-prod      # L3
    dir: 3.data
    workspace: prod
    autoplan:
      enabled: false     # 手动触发: atlantis plan -p data-prod
```

> **Note**: `autoplan: false` 意味着需要手动评论 `atlantis plan` 触发

---

## 6. 变量一致性

### 变量流

```
1Password (SSOT)
     ↓ op item get + gh secret set
GitHub Secrets
     │
     ├──► CI (terraform-plan.yml)
     │         └──► TF_VAR_* (语法检查用)
     │
     └──► Atlantis Pod (helm_release)
               └──► TF_VAR_* (plan/apply 用)
```

### 重要变量

| 变量 | CI 需要 | Atlantis 需要 | 说明 |
|:-----|:-------:|:-------------:|:-----|
| `VAULT_ROOT_TOKEN` | ❌ | ✅ | CI 不做 plan，不需要 |
| `CLOUDFLARE_API_TOKEN` | ✅ | ✅ | validate 需要 |
| `AWS_ACCESS_KEY_ID` | ✅ | ✅ | backend 初始化 |

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
# 在 PR 评论: atlantis plan
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
