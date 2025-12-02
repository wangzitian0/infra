# CI/CD Configuration

## 📍 你在这里

这个目录包含所有 CI/CD 配置。

## 📂 目录结构

```
ci/
├── README.md              → 本文件
├── github-actions/        → GitHub Actions workflows
│   ├── deploy.yml         → 应用部署
│   ├── terraform.yml      → 基础设施变更
│   └── pr-preview.yml     → PR 预览环境
└── atlantis/              → Terraform 自动化
    └── atlantis.yaml      → Atlantis 配置
```

## 🚀 Workflows

### deploy.yml - 应用部署
触发: workflow_dispatch 或 push to main  
功能: 部署应用到指定环境

### terraform.yml - 基础设施变更
触发: PR (terraform/** 路径) 或 workflow_dispatch  
功能: 自动 plan，审批后 apply

### pr-preview.yml - PR 预览
触发: PR opened/synchronized/closed  
功能: 自动创建/销毁预览环境

## 🔧 Atlantis

Terraform PR 自动化工具，通过 PR 评论控制：

```bash
# 查看计划
atlantis plan

# 应用变更
atlantis apply
```

**审批要求**:
- dev: 无需审批
- test: 需要 1 个审批
- staging/prod: 需要审批 + mergeable

## ⚠️ GitHub Secrets 配置

需要在 GitHub 仓库设置以下 Secrets：

- `INFISICAL_CLIENT_ID`
- `INFISICAL_CLIENT_SECRET`
- `INFISICAL_PROJECT_ID`
- `SSH_PRIVATE_KEY`
- `SSH_USER`
- `SSH_HOST`
- `CLOUDFLARE_API_TOKEN`

## 📚 更多文档

- [用户待办](../docs/0.hi_zitian.md) - GitHub Secrets 配置步骤
- [Atlantis 官方文档](https://www.runatlantis.io/)
