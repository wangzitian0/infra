# GitHub Actions Workflows

## 架构概览

```
PR 创建/更新
     │
     ├──► terraform-plan.yml (CI)     ──► infra-flash 评论
     │    fmt/lint/validate
     │    + Integrity Guard (Variable Alignment)
     │
     └──► Atlantis (webhook)          ──► Atlantis 评论
          terraform plan/apply
```

## 密钥注入架构 (CI Refactor)

所有 Workflow 现在统一使用 `secrets_json: ${{ toJSON(secrets) }}` 传递上下文，由 `terraform-setup` Action 内部的 Python 脚本统一解析。这消除了 `deploy-k3s.yml` 中大量的冗余环境变量映射。

**左移守护**：
- **Variable Integrity Check**: 在 CI Validate 阶段运行 `check_integrity.py`，确保所有 TF 变量都在加载器中映射。
- **PEM Strict Check**: 强制验证 RSA 私钥格式。

---

## Workflows

| Workflow | 触发 | 用途 |
|:---------|:-----|:-----|
| [`terraform-plan.yml`](#terraform-ci) | `pull_request` (paths filter) | CI 语法检查 + 完整性校验，为每个 commit 新建 infra-flash 评论 |
| [`infra-flash-update.yml`](#infra-flash-update) | Atlantis 评论 | 追加 Atlantis 状态到 infra-flash 评论 |
| [`deploy-k3s.yml`](#deploy-k3s) | main push (paths filter) / 手动 | Bootstrap/恢复：按顺序 apply L1→L2→L3→L4 |
| [`dig.yml`](#health-check) | `/dig` 评论 | 服务连通性检查 |
| [`docs-site.yml`](#docs-site) | PR / main push / 手动 | 构建 MkDocs 文档站点 |
| [`readme-coverage.yml`](#readme-coverage) | PR / main push | README 更新覆盖率检查（≥80%） |
| [`claude.yml`](#claude-review) | 评论/Review/Issue/Autoplan | AI 代码审查（仅手动触发） |

---
*Last updated: 2025-12-19*
