# 文档导航（k3s bootstrap）

当前范围：只实现“GitHub Actions + Terraform 在 VPS 上部署 k3s”这一件事，IaC 与 infra 都在本仓库，应用通过 `apps/` 子模块引入。

## 必看
- `docs/0.hi_zitian.md`：需要 Zitian 补充/决策的事项
- `docs/change_log/2024-12-04.md`：本次重置的改动记录

## 如何使用（CI 摘要）
1. 在仓库 Secrets 配置 `VPS_HOST`、`VPS_SSH_KEY`（可选：`VPS_USER`、`VPS_SSH_PORT`、`K3S_API_ENDPOINT`、`K3S_CHANNEL`、`K3S_VERSION`、`K3S_CLUSTER_NAME`）。
2. 触发 `Deploy k3s to VPS` 工作流（push main 或手动）。
3. 下载 artifact 中的 kubeconfig，或在本地 `terraform/output/<cluster>-kubeconfig.yaml`。

## 本地运行摘要
```bash
git submodule update --init --recursive
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
cd terraform && terraform init && terraform plan && terraform apply
export KUBECONFIG=./output/truealpha-k3s-kubeconfig.yaml
kubectl get nodes
```

## 参考
- 三层架构与目标： [BRN-004.dev_test_prod_design](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/origin/BRN-004.dev_test_prod_design.md)
