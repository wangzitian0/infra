# GitHub Actions Workflows

## 架构概览

Python 驱动的统一 CI 管道，支持斜杠命令交互。

```mermaid
graph TD
    Push[git push] --> CI[ci.yml]
    CI --> Parse[Parse Event]
    Parse --> Plan[/plan]
    Parse --> Apply[/apply]
    Parse --> Verify[/verify]
    
    Plan --> Dash[Dashboard Update]
    Apply --> Dash
    Verify --> E2E[e2e-tests.yml]
    E2E --> Summary[Job Summary]
```

## Workflows 列表

| Workflow | 触发器 | 职责 |
|:---|:---|:---|
| `ci.yml` | PR / Push / Comment / Dispatch | **统一入口**：解析命令、执行 plan/apply/verify |
| `claude.yml` | `@claude` 评论 | AI 编码/审计任务 |
| `docs-site.yml` | `.md` 文件变动 | 文档站构建部署 |
| `e2e-tests.yml` | Push to main / Dispatch | E2E 回归测试 |
| `readme-coverage.yml` | PR / Push | README 覆盖率检查 |

## 斜杠命令

在 PR 评论中使用：

| 命令 | 作用 |
|:---|:---|
| `/plan` | 预览所有层变更 |
| `/plan bootstrap` | 预览指定层 |
| `/apply` | 部署所有层 |
| `/apply platform` | 部署指定层 |
| `/health` | 健康检查 |
| `/e2e` | E2E 测试 |
| `/review` | AI 审查 |
| `/help` | 显示帮助 |

**兼容旧命令**：`atlantis plan` → `/plan`

## Python CI 模块

核心逻辑在 `0.tools/ci/`：

```
0.tools/ci/
├── __main__.py      # CLI 入口
├── config.py        # 层级定义
├── commands/        # 命令处理器
│   ├── plan.py
│   ├── apply.py
│   ├── verify.py
│   ├── health.py
│   └── parse.py
└── core/            # 核心模块
    ├── terraform.py # TF/Terragrunt 封装
    ├── github.py    # GitHub API
    └── dashboard.py # PR Dashboard
```

## 层级定义

| 层 | 路径 | 引擎 | 部署顺序 |
|:---|:---|:---|:---:|
| bootstrap | `bootstrap/` | terraform | 1 |
| platform | `platform/` | terragrunt | 2 |
| data-staging | `envs/staging/data/` | terragrunt | 3 |
| data-prod | `envs/prod/data/` | terragrunt | 4 |

## Dashboard 格式

```markdown
## ⚙️ Commit `abc1234` Pipeline

| Stage | Status | Output | Time |
|:---|:---:|:---|:---|
| CI Validate | ✅ | [View](#) | 12:34 |
| Plan: bootstrap | ✅ | [View](#) | 12:35 |
| Plan: platform | ⏳ | Running... | - |
| Apply | ⏭️ | - | - |
| AI Review | ⏭️ | - | - |

<!-- next-step -->
⏳ Waiting for plan...
<!-- /next-step -->
```

---

*Last updated: 2025-12-24*