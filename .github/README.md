# infra — k3s + Kubero 基础设施引导

> 📘 **Documentation Site**: [https://wangzitian0.github.io/infra/](https://wangzitian0.github.io/infra/)

> 基于 [BRN-004](../docs/project/BRN-004.md) 的分层架构（L1 Bootstrap → L2 Platform → L3 Data → L4 Apps）。
> 现状：用 **Terraform + GitHub Actions + Atlantis** 在单 VPS 上部署/更新 k3s 平台，并用 PR 流程可审计地推进变更。

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
| `BASE_DOMAIN` | 业务域名（例如 `truealpha.club`） | ✅ |
| `VAULT_POSTGRES_PASSWORD` | Vault 存储用 PostgreSQL 密码 | ✅ |
| `VAULT_ROOT_TOKEN` | Vault Root Token（L2+ apply / Atlantis 运行期密钥） | ✅ |
| `ATLANTIS_WEBHOOK_SECRET` | Atlantis Webhook Secret | ✅ |
| `ATLANTIS_WEB_PASSWORD` | Atlantis Web UI Basic Auth 密码 | ✅ |
| `ATLANTIS_GH_APP_ID` | GitHub App ID（infra-flash/Atlantis 集成） | ✅ |
| `ATLANTIS_GH_APP_KEY` | GitHub App Private Key（PEM） | ✅ |
| `VPS_USER` | SSH 用户（默认 root） | |
| `VPS_SSH_PORT` | SSH 端口（默认 22） | |
| `K3S_API_ENDPOINT` | API 地址（默认 VPS_HOST） | |
| `K3S_CHANNEL` | 安装渠道（默认 stable） | |
| `K3S_VERSION` | 指定版本（留空跟随 channel） | |
| `K3S_CLUSTER_NAME` | 集群名称（默认 truealpha-k3s） | |
| `GH_PAT` | GitHub PAT（可选，用于 Atlantis；优先用 GitHub App） | |
| `GH_OAUTH_CLIENT_ID` | GitHub OAuth Client ID（可选，用于 OAuth2-Proxy） | |
| `GH_OAUTH_CLIENT_SECRET` | GitHub OAuth Client Secret（可选，用于 OAuth2-Proxy） | |
| `INTERNAL_DOMAIN` | Infra 域名（可选，默认同 `BASE_DOMAIN`） | |
| `INTERNAL_ZONE_ID` | Infra 域名 Zone ID（可选） | |

Push 到 main（匹配 workflow 的 paths filter）或手动触发 `Deploy k3s to VPS`（`.github/workflows/deploy-k3s.yml`）。

当前 `deploy-k3s.yml` 为 bootstrap/recovery pipeline：按顺序 apply L1→L2→L3→L4（L3/L4 的 apply/verify 仅在 `push` 事件执行）。

**Pre-flight 验证（Shift-Left）**：
- **Phase 0 (Inputs)**：立即验证所有必填 secrets，<30s 内报错
- **Phase 2 (Dependencies)**：L2 Apply 前验证 Vault 可达性和 Token 有效性

**PR Workflow**:
1. Open PR → CI runs `fmt/tflint/validate` and posts per-commit infra-flash comment.
2. PR 更新（push 新 commit）→ Atlantis autoplan 自动运行 `terraform plan` 并评论结果。
3. Review plan 后评论 `atlantis apply`。

### 3. 本地部署（高级）

Terraform 以 layer 目录为单位运行：`1.bootstrap/2.platform/3.data/4.apps`。

- L1-L4 的变量/密钥以 `TF_VAR_*` 注入为主，参考各 layer 的 README：
  - `../1.bootstrap/README.md`
  - `../2.platform/README.md`
  - `../3.data/README.md`
  - `../4.apps/README.md`

> **TODO（理想态）**
> - 提供本地一键脚本（与 CI 的 state key / workspace 映射完全一致）。

## 目录结构

```
.
├── AGENTS.md                          # [SSOT] AI Agent 行为准则
├── 0.check_now.md                     # [SSOT] 当前待办（5W1H + 验证）
├── apps/                              # [SSOT] 业务代码 (Submodule)
├── 0.tools/                           # [SSOT] 本地工具/脚本
├── 1.bootstrap/                       # [SSOT] L1 Bootstrap
├── 2.platform/                        # [SSOT] L2 Platform
├── 3.data/                            # [SSOT] L3 Data
├── 4.apps/                            # [SSOT] L4 Apps
├── tools/                             # [SSOT] 辅助脚本（CI/校验）
├── project/                           # [SSOT] 实施状态与进度
│   ├── README.md
│   └── BRN-004.md                     # Staging 部署实施
├── docs/                              # [SSOT] 架构设计与文档
│   ├── README.md
│   ├── dir.md                         # 目录结构详解
│   └── ...
└── .github/                           # [SSOT] 自动化工作流
```

## 验证部署

部署成功后，kubeconfig 会输出到不同位置：

| 方式 | kubeconfig 位置 | 获取方法 |
|------|-----------------|----------|
| **CI** | GitHub Artifact | Actions → 对应 Run → Artifacts → `kubeconfig` 下载 |
| **本地** | `1.bootstrap/output/<cluster>-kubeconfig.yaml` | `cd 1.bootstrap && terraform apply` 后自动生成 |

```bash
# 本地验证
cd 1.bootstrap
export KUBECONFIG="$(terraform output -raw kubeconfig_path)"
kubectl get nodes   # 应返回 truealpha-k3s Ready
kubectl get pods -A # 查看所有 pods
```

## 设计提示

- **State 存储**：Cloudflare R2（S3 兼容，无锁）。需要锁请改用 S3+DynamoDB 或 Terraform Cloud。
- **API Endpoint**：可用域名访问 API，需配置 DNS 指向 VPS。
- **SSH Key**：tfvars 中使用 heredoc 保留换行。

## 贡献者提示

- 约定：每次变更更新 `../0.check_now.md`，并同步修改所涉目录的 `README.md`。

> **TODO（理想态）**
> - 增加 `docs-guard`（CI + 本地脚本）强制校验 `0.check_now.md` / README 更新。

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

- [ops.pipeline.md](../docs/ssot/ops.pipeline.md)
- [Workflows README](./workflows/README.md)
- [BRN-004](../docs/project/BRN-004.md)
- [AGENTS.md](../AGENTS.md): AI Agent 工作规范
- [0.check_now.md](../0.check_now.md): 待办与验证清单
