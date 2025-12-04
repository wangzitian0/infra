# Docker Compose Configurations

## 📍 你在这里

这个目录包含所有环境的 Docker Compose 配置文件。

## 🎯 用途

通过 **base + override** 模式管理 5 个环境的服务编排。

## 📂 文件说明

```
compose/
├── README.md      → 本文件
├── base.yml       → 基础服务定义（所有环境共享）
├── dev.yml        → 开发环境覆盖
├── ci.yml         → CI 环境覆盖
├── test.yml       → 测试/PR 预览覆盖
├── staging.yml    → 预发环境覆盖
├── prod.yml       → 生产环境覆盖
└── platform/
    └── infisical.yml → 自托管 Infisical（供 Dokploy API 上传的 compose 模板）
```

## 🚀 快速开始

### 启动服务

```bash
# 开发环境
docker compose \
  -f compose/base.yml \
  -f compose/dev.yml \
  --env-file .env.dev \
  -p truealpha-dev \
  up -d

# 生产环境
docker compose \
  -f compose/base.yml \
  -f compose/prod.yml \
  --env-file .env.prod \
  -p truealpha-prod \
  up -d
```

### 查看状态

```bash
docker compose -p truealpha-dev ps
```

### 查看日志

```bash
docker compose -p truealpha-dev logs -f backend
```

## 📦 服务清单

### base.yml 包含
- **backend**: GraphQL API
- **neo4j**: 图数据库
- **postgres**: 关系数据库
- **redis**: 缓存 & Celery broker
- **celery-worker**: 后台任务
- **celery-beat**: 定时任务
- **flower**: Celery 监控

### 环境差异

| 环境 | 特点 |
|------|------|
| dev | 端口暴露、源码挂载、调试模式 |
| ci | 资源限制、最小化服务 |
| test | 动态域名、共享数据库 |
| staging | 持久化卷、日志轮转 |
| prod | 高可用、副本扩展、安全headers |

## ⚠️ 重要提示

- 环境变量从 Infisical 导出
- 不同环境使用不同的项目名 (-p)
- 生产环境有资源限制和副本数
- 如需自托管 Infisical，通过 Terraform 模块调用 Dokploy API，使用 `platform/infisical.yml`（模板使用 envsubst 变量）

## 📚 更多文档

- [开发者指南](../docs/guides/developer-onboarding.md)
- [部署脚本](../scripts/deploy/)
