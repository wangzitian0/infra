# 文档导航（k3s bootstrap）

当前范围：只实现"GitHub Actions + Terraform 在 VPS 上部署 k3s"这一件事，IaC 与 infra 都在本仓库，应用通过 `apps/` 子模块引入。

## 文档索引

| 文档 | 用途 |
|------|------|
| [BRN-004.env_eaas_design.md](./BRN-004.env_eaas_design.md) | EaaS 设计理念（infra 版），三层架构与目标 |
| [BRN-004.staging_deployment.md](./BRN-004.staging_deployment.md) | Staging 部署完整设计（包括所有选型、命名空间、phases、Terraform 结构） |
| [0.hi_zitian.md](./0.hi_zitian.md) | 用户待办（5W1H），需要 Zitian 补充/决策的事项 |
| [ci-workflow-todo.md](./ci-workflow-todo.md) | CI/CD 工作流设计 TODO（评论驱动、多环境） |
| [change_log/](./change_log/) | 变更日志目录 |

## 如何使用（CI 摘要）
1. 在仓库 Secrets 配置 R2 凭据（`AWS_ACCESS_KEY_ID`、`AWS_SECRET_ACCESS_KEY`、`R2_BUCKET`、`R2_ACCOUNT_ID`）和 VPS 信息（`VPS_HOST`、`VPS_SSH_KEY`）。
2. 触发 `Deploy k3s to VPS` 工作流（push main 或手动）。
3. 下载 artifact 中的 kubeconfig，或在本地 `terraform/output/<cluster>-kubeconfig.yaml`。

## 本地运行摘要
```bash
git submodule update --init --recursive
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# 编辑 terraform.tfvars 填入 VPS/SSH 信息
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... R2_BUCKET=... R2_ACCOUNT_ID=...
cd terraform
terraform init \
  -backend-config="bucket=$R2_BUCKET" \
  -backend-config="endpoints={s3=\"https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com\"}"
terraform plan && terraform apply
export KUBECONFIG=./output/truealpha-k3s-kubeconfig.yaml
kubectl get nodes
```
