# infra（k3s reboot）

> 基于 [BRN-004](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/origin/BRN-004.dev_test_prod_design.md) 的三层架构（IaC → k3s 平台 → apps）。当前只做一件事：用 GitHub Actions + Terraform 把 k3s 装到你的 VPS。

## 目标与状态
- ✅ k3s 部署：Terraform + GitHub Actions 自动安装单节点 k3s，并拉回 kubeconfig。
- ✅ 应用依赖：`apps/` 为 PEG-scaner 子仓库（submodule），保持 infra → apps 单向依赖。
- ⏳ 后续演进：在 k3s 上接入应用、观测、Backstage，但先保证集群可用、流程能跑。

## CI 工作流（推荐，R2 后端）
1. 复制 `terraform/backend.tf.example` 为 `terraform/backend.tf`，替换 `<r2-bucket-name>`、`<account-id>`，确保使用 Cloudflare R2 作为 Terraform state（S3 兼容，无锁）。
2. 准备一台可 SSH 的 VPS，开放 22 与 6443，用户具备 sudo。
3. 在 GitHub Repository Secrets 配置：
   - R2（必填）：`AWS_ACCESS_KEY_ID`、`AWS_SECRET_ACCESS_KEY`
   - VPS（必填）：`VPS_HOST`、`VPS_SSH_KEY`
   - 可选：`VPS_USER`(默认 root)、`VPS_SSH_PORT`(默认 22)、`K3S_API_ENDPOINT`(默认 VPS_HOST)、`K3S_CHANNEL`(默认 stable)、`K3S_VERSION`(留空跟随 channel)、`K3S_CLUSTER_NAME`(默认 truealpha-k3s)
4. 触发工作流 `Deploy k3s to VPS`（推送 main 或手动 dispatch）。
5. 工作流会 fmt/init/plan/apply → 拉回 kubeconfig → `kubectl get nodes` 冒烟 → 上传 kubeconfig artifact。

## 本地运行（可选）
```bash
git submodule update --init --recursive
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# 或使用 .env: cp terraform/.env.example terraform/.env && set -a; source terraform/.env; set +a
# 填写 R2、VPS 主机、用户、SSH 私钥、API 域名等
# 若使用 R2，复制 backend.tf.example 为 backend.tf 并替换占位符
cd terraform
terraform init
terraform plan
terraform apply
export KUBECONFIG=./output/truealpha-k3s-kubeconfig.yaml
kubectl get nodes
```

## 仓库结构
```
.
├── AGENTS.md
├── README.md
├── apps/                           # PEG-scaner 子模块
├── docs/
│   ├── README.md
│   ├── 0.hi_zitian.md
│   └── change_log/2024-12-04.md
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── scripts/install-k3s.sh.tmpl
│   └── terraform.tfvars.example
└── .github/workflows/deploy-k3s.yml
```

## GitHub Secrets 说明
| 名称 | 作用 |
| ---- | ---- |
| `AWS_ACCESS_KEY_ID` | R2 API Token Access Key（必填） |
| `AWS_SECRET_ACCESS_KEY` | R2 API Token Secret Key（必填） |
| `VPS_HOST` | VPS 公网 IP 或域名（必填） |
| `VPS_SSH_KEY` | SSH 私钥内容，具备 sudo 权限（必填） |
| `VPS_USER` | SSH 用户，缺省为 root |
| `VPS_SSH_PORT` | SSH 端口，缺省 22 |
| `K3S_API_ENDPOINT` | kube-apiserver 对外地址，缺省 VPS_HOST |
| `K3S_CHANNEL` | k3s 安装渠道（stable/latest 等） |
| `K3S_VERSION` | 指定 k3s 版本（留空则跟随 channel） |
| `K3S_CLUSTER_NAME` | 集群名称，缺省 truealpha-k3s |

## 工作流细节
- 路径：`.github/workflows/deploy-k3s.yml`
- 过程：写 tfvars + ssh key → terraform fmt/init/plan/apply → 拉 kubeconfig、替换 API Endpoint、kubectl 冒烟 → 上传 artifact。
- 输出：`terraform/output/<cluster>-kubeconfig.yaml`（本地）或 CI artifact 下载。

## 设计提示
- 三层模型：**IaC(Terraform)** → **Infra(k3s)** → **Apps(PEG-scaner)**，只保留单向依赖。
- 秘钥不入库：真实 tfvars/私钥仅存在本地或 GitHub Secrets。
- 先跑通 k3s，再逐步加应用/观测/Backstage。

## 相关
- BRN-004 设计文档（全链路理念）：[链接](https://github.com/wangzitian0/PEG-scaner/blob/main/docs/origin/BRN-004.dev_test_prod_design.md)
