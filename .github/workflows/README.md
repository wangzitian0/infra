# GitHub Workflows

> **Role**: CI/CD Automation Definitions
> **Executor**: GitHub Actions

This directory contains workflow definitions that drive the infrastructure pipeline.
All complex logic lives in `tools/ci/` Python modules.

## 📚 SSOT References

For the authoritative pipeline architecture and logic, refer to:
> [**Pipeline SSOT**](../../docs/ssot/ops.pipeline.md)

## Workflows

| Workflow | 触发器 | 职责 |
|:---|:---|:---|
| `ci.yml` | PR / Push / Comment / Dispatch | **统一入口**：路由(parse) -> Digger/PyCI 调度 |
| `claude.yml` | `@claude` 评论 | AI 编码/审计任务 |
| `docs-site.yml` | `.md` 文件变动 | 文档站构建部署 |
| `e2e-tests.yml` | Push to main / Dispatch | E2E 回归测试 |
| `readme-coverage.yml` | PR / Push | README 覆盖率检查 |
| `ops-drift-fix.yml` | `schedule` | Auto-fix drift (e.g., Vault tokens). |

---

## PR 交互设计

### 命令流程
```
用户评论 /plan
    ├─→ 👀 立即响应 (emoji react)
    ├─→ 📝 立即评论: "⏳ Running... [View Job](link)"
    ├─→ [Job 运行中...]
    └──→ 📝 更新评论为 Dashboard (结果表格)
```

### Dashboard 评论 (单一评论，持续更新)
```markdown
## 🚀 CI Dashboard

| Stage | Status | Duration | Link |
|-------|--------|----------|------|
| Plan: L1 | ✅ | 12s | [📋](run_link) |
| Plan: L2 | ⏳ | - | [👁️](run_link) |

> 触发: `/plan` by @user
```

### 双向链接

| 从 | 到 | 内容 |
|----|----|----|
| PR 评论 | Workflow Run | `[View Job](actions/runs/xxx)` |
| Workflow Run | PR | Commit Status (PR Checks) |
| 失败 Issue | PR | `Triggered by: PR #123` |
| 失败 Issue | Workflow Run | `[Failed Run](link)` |

### 响应时间目标

| 事件 | 响应延迟 |
|------|---------|
| 用户评论 | <1s emoji react |
| Job 启动 | <5s 初始评论 |
| 阶段完成 | <3s 更新 Dashboard |
| 结束 | <3s 最终状态 + Commit Status |

---
*Last updated: 2025-12-25*

