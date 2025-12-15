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
| [`terraform-plan.yml`](#terraform-ci) | PR push | CI 语法检查，为每个 commit 新建 infra-flash 评论 |
| [`infra-flash-update.yml`](#infra-flash-update) | Atlantis 评论 | 追加 Atlantis 状态到 infra-flash 评论 |
| [`deploy-k3s.yml`](#deploy-k3s) | 手动 | 初始 K3s 集群部署 |
| [`dig.yml`](#health-check) | `/dig` 评论 | 服务连通性检查 |
| [`claude.yml`](#claude-review) | `/review` 评论 | AI 代码审查 |

---

## terraform-plan.yml {#terraform-ci}

**触发**: PR 修改 `1.bootstrap/`, `2.platform/`, `3.data/`

### 执行步骤

1. `terraform fmt -check -recursive` - 格式检查
2. `tflint` - Lint 检查 (L1/L2/L3)
3. `terraform validate` - 语法验证 (L1/L2/L3)
4. **发布 infra-flash 评论**：每个 commit push 新建一条评论，记录 CI 结果和下一步指引

### infra-flash 评论（Per-Commit）

- PR 中**每个 commit**都会生成独立评论：`<!-- infra-flash-commit:abc1234 -->`
- 评论包含 CI 表格、失败时的修复命令、以及下一步动作（例如 `atlantis plan`）
- 新 commit push 不会覆盖旧评论，形成完整审计链

```markdown
<!-- infra-flash-commit:abc1234 -->
## ⚡ Commit `abc1234`

### CI Validate ✅ | 12:30 UTC

| Layer | Format | Lint | Validate |
|:------|:------:|:----:|:--------:|
| L1 Bootstrap | ✅ | ✅ | ✅ |
| L2 Platform | ✅ | ✅ | ✅ |
| L3 Data | ✅ | ⏭️ | ⏭️ |

👉 **Next:** Comment `atlantis plan` to run plan
```

### Atlantis（本仓库为手动触发）

本仓库 `atlantis.yaml` 将 `autoplan.enabled=false`（避免误触发与并行噪音），因此 CI 通过后需要手动评论触发：
- `atlantis plan`：生成 plan 并由 `infra-flash-update.yml` 追加状态到对应 commit 评论
- `atlantis apply`：review plan 后执行 apply，成功后提示可合并

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

---

## deploy-k3s.yml {#deploy-k3s}

**触发**: `workflow_dispatch` (手动)

用于首次部署 K3s 集群。日常变更通过 Atlantis 处理。

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

**触发**: PR 评论 `/review`, `@claude`, `PTAL`

AI 代码审查：
- 检查 Terraform 结构
- 验证 SSOT 一致性
- 识别潜在问题

---

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

- [Pipeline SSOT](../../docs/ssot/pipeline.md) - 完整流程设计
- [Secrets SSOT](../../docs/ssot/secrets.md) - 密钥管理
- [Atlantis Docs](https://www.runatlantis.io/docs/using-atlantis.html)
