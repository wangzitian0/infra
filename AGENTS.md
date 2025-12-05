

!!! AI 不可以自动修改本文件。当 AI 认为完工，应逐项检查本文件要求后再宣布完成。

# 🚨 强制规则
- 必关联 BRN-004（或后续 infra BRN）
- 先读后写：改某层前先读该层 README/注释
- 改 Terraform：先 `terraform fmt -check` + `terraform plan`
- 必更文档：同步 README / change_log / 相关指南
- 宁空勿错：不确定的值留空或占位
- 控制范围：当前 MVP 聚焦单 VPS k3s，引导 Kubero/观测后置
- 不要过度设计：单 VPS 优先，最小依赖

# 仓库定位与原则
- 角色：BRN-004 环境层（IaC → k3s → Apps）
- 第一原则：本地/CI 命令与变量一致，plan 输出一致，资源状态一致
- 设计：简化、正交；开源、自托管、单人强控、可扩展

# Phase 路线（phase 内无依赖）
- Phase 0.x：k3s + Infisical（后续密码都进 Infisical）
- Phase 1.x：Kubernetes Dashboard、Kubero、Kubero UI、平台 PostgreSQL
- Phase 2.x：数据服务（应用 PostgreSQL、Neo4j、Redis、ClickHouse）
- Phase 3.x：可观测/产品分析（SigNoz、PostHog）

# 目录说明（根 + 一级，按实际）
- `AGENTS.md`：AI 使用规范
- `0.check_now.md`：5W1H 待办与验证清单（当前唯一执行任务）
- `README.md`：人类快速上手
- `docs/`：设计/部署文档、导航、变更记录
- `terraform/`：IaC 代码（k3s/Infisical/DB/UI phases + scripts + outputs）
- `.github/workflows/`：CI 工作流（部署 k3s）
- `apps/`：业务子模块，只读引用
- `node_modules/`：依赖目录（无需关注内容）

# Terraform 变更流程
1. 修改 .tf
2. `terraform fmt -check`
3. `terraform plan`
4. 确认后更新 README/change_log，再提交或 PR（push main 触发 CI）

# State / 凭据
- 后端：Cloudflare R2（S3 兼容，无锁），`backend.tf` 入库，bucket/endpoint 用 `-backend-config`
- 凭据：`AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` 通过环境或 CI Secrets
- VPS 信息：`VPS_HOST`、`VPS_SSH_KEY`（可选 `VPS_USER`、`VPS_SSH_PORT`）
- 可选 k3s 参数：`K3S_API_ENDPOINT`、`K3S_CHANNEL`、`K3S_VERSION`、`K3S_CLUSTER_NAME`

# 敏感文件（不入库）
- `terraform/terraform.tfvars`
- `*.pem` / `*.key`

# 文档职责
- `0.check_now.md`（根）：5W1H 待办 + 验证清单
- `docs/change_log/*.md`：每次改动后更新
- `README.md`：快速上手
- `docs/README.md`：文档导航
- 本文件：长期规范

# CI/CD（deploy-k3s.yml）
- 触发：push main（terraform/** 或自身），或 workflow_dispatch
- 必填 Secrets：`AWS_ACCESS_KEY_ID`、`AWS_SECRET_ACCESS_KEY`、`R2_BUCKET`、`R2_ACCOUNT_ID`、`VPS_HOST`、`VPS_SSH_KEY`
- 步骤：Checkout → Setup Terraform → Render tfvars → fmt → init → plan → apply → 拉 kubeconfig → Smoke test → Upload artifact

# 参考
- docs/BRN-004.env_eaas_design.md
- docs/BRN-004.staging_deployment.md
- docs/ci-workflow-todo.md
- 0.check_now.md
- 外部：IRD-004.env_eaas_infra、TRD-004.env_eaas_implementation
