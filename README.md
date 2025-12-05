# infra — k3s + Kubero 基础设施引导

> 基于 [BRN-004 EaaS 设计](./docs/BRN-004.env_eaas_design.md) 的三层架构（IaC → k3s 平台 → Apps）。
> 当前只做一件事：用 **Terraform + GitHub Actions** 把 k3s 装到你的 VPS，并为后续 Kubero/Kubero UI 提供底座。

## 快速开始

### 1. 准备 VPS
- 公网 IP 或域名
- 开放端口：22 (SSH)、6443 (k8s API)
- Ubuntu 22.04+ / Debian 11+，账户可 sudo

### 2. CI 部署（推荐）

在 GitHub Repository Secrets 配置：

| Secret | 说明 | 必填 |
|--------|------|------|
| `AWS_ACCESS_KEY_ID` | R2 Access Key（S3 兼容 API） | ✅ |
| `AWS_SECRET_ACCESS_KEY` | R2 Secret Key（S3 兼容 API） | ✅ |
| `R2_BUCKET` | R2 Bucket 名称 | ✅ |
| `R2_ACCOUNT_ID` | Cloudflare Account ID | ✅ |
| `VPS_HOST` | VPS 公网 IP 或域名 | ✅ |
| `VPS_SSH_KEY` | SSH 私钥内容 | ✅ |
| `VPS_USER` | SSH 用户（默认 root） | |
| `VPS_SSH_PORT` | SSH 端口（默认 22） | |
| `K3S_API_ENDPOINT` | API 地址（默认 VPS_HOST） | |
| `K3S_CHANNEL` | 安装渠道（默认 stable） | |
| `K3S_VERSION` | 指定版本（留空跟随 channel） | |
| `K3S_CLUSTER_NAME` | 集群名称（默认 truealpha-k3s） | |

Push 到 main 或手动触发 `Deploy k3s to VPS` 工作流（`.github/workflows/deploy-k3s.yml`）。

### 3. 本地部署（可选）

```bash
cd terraform

# 1. 设置环境变量（Terraform 读取 AWS_*，R2_* 用于构造 backend-config）
export AWS_ACCESS_KEY_ID=<your-r2-access-key>      # Terraform S3 backend 凭据
export AWS_SECRET_ACCESS_KEY=<your-r2-secret-key>  # Terraform S3 backend 凭据
export R2_BUCKET=<your-bucket-name>                # 用于 -backend-config
export R2_ACCOUNT_ID=<your-cloudflare-account-id>  # 用于 -backend-config

# 2. 复制变量模板并填入 VPS/SSH 信息
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars

# 3. 初始化（和 CI 使用相同的 -backend-config 参数）
terraform init \
  -backend-config="bucket=$R2_BUCKET" \
  -backend-config="endpoints={s3=\"https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com\"}"

# 4. 计划和部署
terraform plan
# terraform apply  # 真正部署时取消注释 

# 5. 验证（apply 后）
export KUBECONFIG=./output/truealpha-k3s-kubeconfig.yaml
kubectl get nodes
```

## 目录结构

```
.
├── AGENTS.md                          # AI Agent 工作规范
├── 0.check_now.md                     # 待办 + 验证清单
├── README.md                          # 快速上手（本文件）
├── apps/                              # PEG-scaner 子模块
├── docs/
│   ├── README.md                      # 文档导航
│   ├── BRN-004.env_eaas_design.md     # EaaS 设计理念
│   ├── ci-workflow-todo.md            # CI/CD 工作流设计 TODO
│   └── change_log/                    # 变更日志
├── terraform/
│   ├── main.tf                        # 核心资源
│   ├── variables.tf                   # 变量定义
│   ├── outputs.tf                     # 输出定义
│   ├── backend.tf                     # R2 后端（bucket/endpoint 通过 -backend-config 传入）
│   ├── scripts/install-k3s.sh.tmpl    # k3s 安装脚本
│   ├── output/                        # kubeconfig 输出（gitignored）
│   └── terraform.tfvars.example       # 本地变量模板
└── .github/workflows/deploy-k3s.yml   # CI 工作流
```

## 工作流输出

成功后可获取 kubeconfig：
- **CI**：下载 workflow artifact
- **本地**：`terraform/output/<cluster>-kubeconfig.yaml`

```bash
export KUBECONFIG=./output/truealpha-k3s-kubeconfig.yaml
kubectl get nodes
# 应返回单节点 Ready 状态
```

## 设计提示

- **State 存储**：Cloudflare R2（S3 兼容，无锁）。需要锁请改用 S3+DynamoDB 或 Terraform Cloud。
- **API Endpoint**：可用域名访问 API，需配置 DNS 指向 VPS。
- **SSH Key**：tfvars 中使用 heredoc 保留换行。

## 后续演进

**BRN-004：Staging 完整部署（进行中）**

- [x] Phase 0.0: k3s 引导
- [x] Phase 0.1: Infisical (Secrets Management, 依赖 PostgreSQL)
- [x] Phase 0.2: Kubernetes Dashboard
- [ ] Phase 1.1: PostgreSQL (Application database)
- [ ] Phase 2.x: Redis + Neo4j (密码管理通过 Infisical)
- [ ] Phase 3.x: Kubero + Kubero UI
- [ ] Phase 4.x: SigNoz + PostHog (Observability)

**BRN-007：多环境自动化（后期）**

- [ ] 五环境配置（dev/ci/test/staging/prod）
- [ ] 评论驱动 CI/CD（`/plan`, `/apply` 命令）
- [ ] 可观测性（SigNoz + PostHog）
- [ ] 开发者门户（Backstage）

## 相关文档

- [BRN-004: EaaS 设计理念](./docs/BRN-004.env_eaas_design.md)
- [AGENTS.md](./AGENTS.md): AI Agent 工作规范
- [0.check_now.md](./0.check_now.md): 待办与验证清单
