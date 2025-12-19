# 密钥管理 SSOT

> **一句话**：所有密钥的 Single Source of Truth 在 1Password，GitHub Secrets 是部署缓存，CI 运行时通过 Python 加载器统一注入。

## 信息流架构

```mermaid
graph LR
    OP[1Password<br/>my_cloud vault] -->|"op + gh 脚本同步"| GH[GitHub Secrets]
    GH -->|"toJSON(secrets)"| Loader["0.tools/ci_load_secrets.py<br/>(Python Loader)"]
    Loader -->|导出 TF_VAR_*| TF[Terraform]
    TF -->|Helm values| K8S[Kubernetes]
    K8S -->|运行时注入| VAULT[Vault]
```

**核心逻辑**：
- **存储**：1Password 是唯一的 master 记录。
- **分发**：GitHub Secrets 仅作为中间缓存，不负责业务逻辑。
- **注入**：`ci_load_secrets.py` 负责将 GitHub Secrets 映射为 IaC 环境所需的 `TF_VAR_` 变量，实现变量链条的 DRY（不重复）。

---

## 密钥清单

### 1. 1Password → GitHub Secrets 映射

同步所有密钥到 GitHub 的一键命令：

```bash
# 执行此命令前需 op signin
op item get "Infra-GHA-Secrets" --vault="my_cloud" --format json |
  jq -r '.fields[] | select(.value != null) | "\(.label) \(.value)"' |
  while read -r key value; do
    if [[ $key =~ ^[A-Z_]+$ ]]; then
      echo "Syncing $key..."
      gh secret set "$key" --body "$value"
    fi
  done
```

| 1Password 项目 | 字段（Label） | GitHub Secret | 映射后的 TF_VAR |
|----------------|---------------------|---------------|-----------------|
| `Infra-Cloudflare` | `BASE_DOMAIN` | `BASE_DOMAIN` | `base_domain` |
| | `CLOUDFLARE_ZONE_ID` | `CLOUDFLARE_ZONE_ID` | `cloudflare_zone_id` |
| | `INTERNAL_DOMAIN` | `INTERNAL_DOMAIN` | `internal_domain` |
| | `INTERNAL_ZONE_ID` | `INTERNAL_ZONE_ID` | `internal_zone_id` |
| | `CLOUDFLARE_API_TOKEN` | `CLOUDFLARE_API_TOKEN` | `cloudflare_api_token` |
| `Infra-R2` | `R2_BUCKET` | `R2_BUCKET` | `r2_bucket` |
| | `R2_ACCOUNT_ID` | `R2_ACCOUNT_ID` | `r2_account_id` |
| | `AWS_ACCESS_KEY_ID` | `AWS_ACCESS_KEY_ID` | `aws_access_key_id` |
| | `AWS_SECRET_ACCESS_KEY` | `AWS_SECRET_ACCESS_KEY` | `aws_secret_access_key` |
| `Infra-VPS` | `VPS_HOST` | `VPS_HOST` | `vps_host` |
| | `VPS_SSH_KEY` | `VPS_SSH_KEY` | `ssh_private_key` |
| `PostgreSQL (Platform)` | `VAULT_POSTGRES_PASSWORD` | `VAULT_POSTGRES_PASSWORD` | `vault_postgres_password` |
| `Infra-OAuth` | `GH_OAUTH_CLIENT_ID` | `GH_OAUTH_CLIENT_ID` | `github_oauth_client_id` |
| | `GH_OAUTH_CLIENT_SECRET` | `GH_OAUTH_CLIENT_SECRET` | `github_oauth_client_secret` |
| `Infra-Atlantis` | `ATLANTIS_WEBHOOK_SECRET` | `ATLANTIS_WEBHOOK_SECRET` | `atlantis_webhook_secret` |
| | `ATLANTIS_WEB_PASSWORD` | `ATLANTIS_WEB_PASSWORD` | `atlantis_web_password` |
| | `ATLANTIS_GH_APP_ID` | `ATLANTIS_GH_APP_ID` | `github_app_id` |
| | `ATLANTIS_GH_APP_KEY` | `ATLANTIS_GH_APP_KEY` | `github_app_key` |
| `Infra-Vault` | `VAULT_ROOT_TOKEN` | `VAULT_ROOT_TOKEN` | `vault_root_token` |
| `Infra-GHA-Secrets` | `api_key` | `GEMINI_API_KEY` | - |
| `GitHub PAT` | `token` | `GH_PAT` | `github_token` |

### 2. 运行时默认变量 (Loader 自动处理)

以下变量由 `ci_load_secrets.py` 在缺失时自动填充默认值：
- `VPS_USER`: `root`
- `VPS_SSH_PORT`: `22`
- `K3S_CLUSTER_NAME`: `truealpha-k3s`
- `K3S_CHANNEL`: `stable`

---

## 实施状态

| 组件 | 状态 |
|------|------|
| 1Password SSOT | ✅ 已覆盖 24+ 核心字段 |
| Python Loader | ✅ `0.tools/ci_load_secrets.py` 已上线 |
| Workflow DRY | ✅ `deploy-k3s.yml` 冗余减少 80% |
| 变量链条 | ✅ 1Password -> GH -> Env -> TF 闭环 |

---

## 维护 SOP

### 1. 新增一个密钥
1.  在 1Password 对应条目中增加字段（Label 建议大写）。
2.  在 `0.tools/ci_load_secrets.py` 的 `MAPPING` 字典中增加一行映射。
3.  运行同步脚本更新 GitHub Secrets。
4.  在 Terraform `.tf` 文件中使用变量。

### 2. 密钥泄露/轮换
1.  在 1Password 中更新真值。
2.  重新运行同步脚本。
3.  重新触发 CI 流水线（`atlantis plan` / `push to main`）。

### 3. 新增独立 GHA 密钥 (如 GEMINI_API_KEY)

对于仅在工作流中使用、不参与 Terraform 的密钥：

1.  在 1Password 的 `Infra-GHA-Secrets` 项目中新增一个字段（Label 为 `GEMINI_API_KEY`）。

2.  运行一键同步脚本（见上文）将其推送到 GitHub。



3.  在 `.github/workflows/*.yml` 中通过 `${{ secrets.GEMINI_API_KEY }}` 引用。



---

> 变更记录见 [change_log/](../change_log/README.md)
