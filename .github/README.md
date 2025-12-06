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
| `CLOUDFLARE_API_TOKEN` | Cloudflare API Token (DNS/Cert) | ✅ |
| `CLOUDFLARE_ZONE_ID` | Cloudflare Zone ID | ✅ |
| `VPS_USER` | SSH 用户（默认 root） | |
| `VPS_SSH_PORT` | SSH 端口（默认 22） | |
| `K3S_API_ENDPOINT` | API 地址（默认 VPS_HOST） | |
| `K3S_CHANNEL` | 安装渠道（默认 stable） | |
| `K3S_VERSION` | 指定版本（留空跟随 channel） | |
| `K3S_CLUSTER_NAME` | 集群名称（默认 truealpha-k3s） | |

Push 到 main 或手动触发 `Deploy k3s to VPS` 工作流（`.github/workflows/deploy-k3s.yml`）。

**PR Workflow**:
1. Open PR → CI runs `terraform plan`.
2. On success → CI comments `atlantis plan`.
3. Atlantis bot comments plan result.
4. You comment `atlantis apply`.

### 3. 本地部署（可选）

```bash
# 1. 设置环境变量
export AWS_ACCESS_KEY_ID="<your-r2-access-key>"
export AWS_SECRET_ACCESS_KEY="<your-r2-secret-key>"
export R2_BUCKET="<your-bucket-name>"
export R2_ACCOUNT_ID="<your-cloudflare-account-id>"
export VPS_HOST="<your-vps-ip>"
export INFISICAL_POSTGRES_PASSWORD="<strong-password>"

# 2. 初始化 Terraform（一键）
cd terraform && terraform init \
  -backend-config="bucket=$R2_BUCKET" \
  -backend-config="endpoints={s3=\"https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com\"}"

# 3. 创建 tfvars（填入 VPS/SSH 信息）
cp terraform.tfvars.example terraform.tfvars
# 编辑 terraform.tfvars 填入 vps_host, ssh_private_key 等

# 4. 部署
terraform plan && terraform apply
```

## 目录结构

```
.
├── AGENTS.md                          # [SSOT] AI Agent 行为准则
├── 0.check_now.md -> docs/change_log  # [SSOT] 当前待办 (Symlink)
├── README.md                          # [SSOT] 项目入口
├── apps/                              # [SSOT] 业务代码 (Submodule)
├── project/                           # [SSOT] 实施状态与进度
│   ├── README.md
│   └── BRN-004.md                     # Staging 部署实施
├── docs/                              # [SSOT] 架构设计与文档
│   ├── README.md
│   ├── dir.md                         # 目录结构详解
│   └── ...
├── terraform/                         # [SSOT] 基础设施状态 (IaC)
│   ├── README.md
│   └── ...
└── .github/                           # [SSOT] 自动化工作流
```

## 验证部署

部署成功后，kubeconfig 会输出到不同位置：

| 方式 | kubeconfig 位置 | 获取方法 |
|------|-----------------|----------|
| **CI** | GitHub Artifact | Actions → 对应 Run → Artifacts → `kubeconfig` 下载 |
| **本地** | `terraform/output/<cluster>-kubeconfig.yaml` | apply 后自动生成 |

```bash
# 本地验证
export KUBECONFIG=~/zitian/infra/terraform/output/truealpha-k3s-kubeconfig.yaml
kubectl get nodes   # 应返回 truealpha-k3s Ready
kubectl get pods -A # 查看所有 pods
```

## 设计提示

- **State 存储**：Cloudflare R2（S3 兼容，无锁）。需要锁请改用 S3+DynamoDB 或 Terraform Cloud。
- **API Endpoint**：可用域名访问 API，需配置 DNS 指向 VPS。
- **SSH Key**：tfvars 中使用 heredoc 保留换行。

## 贡献者提示

- 每次变更必须更新 `0.check_now.md`，并同步修改所涉目录的 `README.md`（CI `Documentation Guard` 会检查）。
- 本地执行 `./tools/docs-guard.sh origin/main` 可提前验证。

## 后续演进

**BRN-004：Staging 完整部署（phase 内无依赖）**

- Phase 0.x：k3s + Infisical（后续所有密码都存 Infisical）
- Phase 1.x：Kubernetes Dashboard、Kubero、Kubero UI、应用 PostgreSQL
- Phase 2.x：数据服务（Neo4j、Redis、ClickHouse）
- Phase 3.x：可观测/产品分析（SigNoz、PostHog）

**BRN-007：多环境自动化（后期）**

- [ ] 五环境配置（dev/ci/test/staging/prod）
- [ ] 评论驱动 CI/CD（`/plan`, `/apply` 命令）
- [ ] 可观测性（SigNoz + PostHog）
- [ ] 开发者门户（Backstage）

## 相关文档

- [BRN-004: EaaS 设计理念](./docs/BRN-004.env_eaas_design.md)
- [AGENTS.md](./AGENTS.md): AI Agent 工作规范
- [0.check_now.md](./0.check_now.md): 待办与验证清单
