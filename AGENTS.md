# AI Agent 工作指南（极简 k3s 引导）

## 仓库与依赖
- 本仓库：infra（Terraform + GitHub Actions，用于在 VPS 安装单节点 k3s）。
- 应用仓库：apps/ 子模块 -> https://github.com/wangzitian0/PEG-scaner （保持单向依赖 infra → apps，禁止软链）。
- 文档引用：PEG-scaner 文档必须用完整 GitHub URL，例如  
  `https://github.com/wangzitian0/PEG-scaner/blob/main/docs/origin/BRN-004.dev_test_prod_design.md`

## 当前范围
- 只做一件事：自动把 k3s 装到 VPS，并产出 kubeconfig（CI + Terraform）。
- 状态：Dokploy/compose 等已移除，运行时统一为 k3s；Terraform state 统一放 Cloudflare R2（S3 兼容，无锁）。

## 目录
```
.
├── AGENTS.md
├── README.md
├── apps/                          # PEG-scaner 子模块
├── docs/
│   ├── README.md
│   ├── 0.hi_zitian.md             # 用户待办（5W1H+hints）
│   └── change_log/2024-12-04.md   # 本次变更记录
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── scripts/install-k3s.sh.tmpl
│   ├── terraform.tfvars.example   # 本地/CI 填参示例
│   ├── .env.example               # 本地 plan: TF_VAR_* 模板
│   └── backend.tf.example         # R2 后端模板（必须复制为 backend.tf 替换占位符）
└── .github/workflows/deploy-k3s.yml
```

## 工作流
- CI（推荐）：`.github/workflows/deploy-k3s.yml`
  - 准备：复制 `terraform/backend.tf.example` -> `terraform/backend.tf` 并替换 R2 bucket/account；Repository Secrets 填 `AWS_ACCESS_KEY_ID`、`AWS_SECRET_ACCESS_KEY`（R2），必填 `VPS_HOST`、`VPS_SSH_KEY`，可选 `VPS_USER`、`VPS_SSH_PORT`、`K3S_API_ENDPOINT`(默认 VPS_HOST)、`K3S_CHANNEL`、`K3S_VERSION`、`K3S_CLUSTER_NAME`。
  - 步骤：生成 tfvars+SSH key → terraform fmt/init/plan/apply → 拉 kubeconfig → `kubectl get nodes` 冒烟 → 上传 artifact。
- 本地 plan/apply：
  - 方式1：`cp terraform/terraform.tfvars.example terraform/terraform.tfvars` 填值后 `cd terraform && terraform init && terraform plan && terraform apply`
  - 方式2：`cp terraform/.env.example terraform/.env` 填值后 `set -a; source terraform/.env; set +a; cd terraform; terraform init; terraform plan && terraform apply`
  - kubeconfig 输出：`terraform/output/<cluster>-kubeconfig.yaml`

## 规则
- 用户待办：有需用户填写/决策的，更新 `docs/0.hi_zitian.md`（一级标题=事项，二级=5W1H+hints）。
- 变更记录：更新 `docs/change_log/2024-12-04.md`。
- app 子模块：`git submodule update --init --recursive`；更新用 `--remote --merge` 或进入 apps 拉 main；禁止软链。
- Secrets/.env/tfvars/私钥不入库；CI 用 Secrets，本地用未跟踪的 tfvars 或 .env。
- Terraform 变更先 `terraform fmt` + `terraform plan`，再改文档与 change_log。

## 提示
- R2 为必选后端（无锁）；需要锁请改用 S3+DynamoDB 或 Terraform Cloud 后调整 backend。
- `K3S_API_ENDPOINT` 可不填，默认使用 `VPS_HOST`；如需域名证书，请填域名并在 DNS 指向 VPS。
- `TF_VAR_ssh_private_key` 需保留换行，可在 .env 中用 `\n` 逃逸，或直接用 tfvars 多行字面量。
