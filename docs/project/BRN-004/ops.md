# BRN-004 运维与操作入口

聚合与本项目直接相关的操作手册，指向已有 runbooks/SOP，避免重复。

## 通用流程
- **通用部署 SOP**: `docs/deployment-sop.md`  
- **Secrets 导出**: `scripts/deploy/export-secrets.sh <env>`（依赖 Infisical）
- **部署脚本**: `scripts/deploy/deploy.sh`（按 `ENV` 变量）

## 环境特定
- **Staging**: `docs/env.d/staging_sop.md` + `terraform/envs/staging/STATUS.md`
- **Test (PR 预览)**: `docs/env.d/test_sop.md` + `terraform/envs/test/STATUS.md`
- **Prod**: `docs/env.d/prod_sop.md` + `terraform/envs/prod/STATUS.md`

## 运行时与观测
- **Compose 入口**: `compose/`（base + 环境覆盖）
- **可观测性**: `observability/signoz/`
- **PostHog**: `analytics/posthog/`
- **Backstage**: `backstage/`（入口与未来健康检查）

## 故障/排障
- **常规运维**: `docs/runbooks/operations.md`
- **架构参考**: `docs/architecture.md`
- **变更记录**: `docs/change_log/BRN-004.md`

## 规则
- 设计变更需先更新 PEG-scaner IRD/TRD，再同步实施文档  
- 新增/调整操作文档优先在本文件或链接的 runbooks/SOP 中更新，避免新增散落文件
