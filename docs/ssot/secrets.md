# 密钥管理 SSOT

> **一句话**：所有密钥的 Single Source of Truth 在 1Password，GitHub Secrets 是部署副本，可随时从 1Password 恢复。

## 信息流架构

```mermaid
graph LR
    OP[1Password<br/>my_cloud vault] -->|"op item get + gh secret set"| GH[GitHub Secrets]
    GH -->|"${{ secrets.* }}"| CI[GitHub Actions]
    CI -->|TF_VAR_*| TF[Terraform]
    TF -->|Helm values| K8S[Kubernetes]
    K8S -->|运行时| VAULT[Vault]
```

**灾难恢复**：GitHub Secrets 丢失 → 从 1Password 恢复所有值

---

## 密钥清单

### 1Password → GitHub Secrets 映射

| 1Password 项目 | 字段 | GitHub Secret | 用途 |
|----------------|------|---------------|------|
| `Cloudflare API` | BASE_DOMAIN | `BASE_DOMAIN` | 主域名 |
| | CLOUDFLARE_ZONE_ID | `CLOUDFLARE_ZONE_ID` | 主 Zone |
| | INTERNAL_DOMAIN | `INTERNAL_DOMAIN` | 内部域名 |
| | INTERNAL_ZONE_ID | `INTERNAL_ZONE_ID` | 内部 Zone |
| | CLOUDFLARE_API_TOKEN | `CLOUDFLARE_API_TOKEN` | DNS 管理 |
| `R2 Backend (AWS)` | R2_BUCKET | `R2_BUCKET` | TF State |
| | R2_ACCOUNT_ID | `R2_ACCOUNT_ID` | R2 账户 |
| | AWS_ACCESS_KEY_ID | `AWS_ACCESS_KEY_ID` | R2 认证 |
| | AWS_SECRET_ACCESS_KEY | `AWS_SECRET_ACCESS_KEY` | R2 认证 |
| `VPS SSH` | VPS_HOST | `VPS_HOST` | VPS IP |
| | VPS_SSH_KEY | `VPS_SSH_KEY` | SSH 私钥 |
| `PostgreSQL (Platform)` | VAULT_POSTGRES_PASSWORD | `VAULT_POSTGRES_PASSWORD` | PG 密码 |
| `GitHub OAuth` | GH_OAUTH_CLIENT_ID | `GH_OAUTH_CLIENT_ID` | OAuth |
| | GH_OAUTH_CLIENT_SECRET | `GH_OAUTH_CLIENT_SECRET` | OAuth |
| `Casdoor Portal Gate` | client_secret | `CASDOOR_PORTAL_CLIENT_SECRET` | Portal SSO Gate OAuth（留空则 TF 自动生成） |
| `Atlantis` | ATLANTIS_WEBHOOK_SECRET | `ATLANTIS_WEBHOOK_SECRET` | Webhook |
| | ATLANTIS_WEB_PASSWORD | `ATLANTIS_WEB_PASSWORD` | Web 密码 |
| | ATLANTIS_GH_APP_ID | `ATLANTIS_GH_APP_ID` | App ID |
| | ATLANTIS_GH_APP_KEY | `ATLANTIS_GH_APP_KEY` | App 私钥 |
| `Vault (zitian.party)` | Unseal Key | `VAULT_UNSEAL_KEY` | 解封 |
| | Root Token | `VAULT_ROOT_TOKEN` | L2/L3 TF Provider |
| `Casdoor Admin` | password | `CASDOOR_ADMIN_PASSWORD` | SSO 管理员密码 |

### 额外 GitHub Secrets（非 1Password 管理）

| Secret | 用途 | 备注 |
|--------|------|------|
| `CLAUDE_CODE_OAUTH_TOKEN` | Claude Code 集成 | 单独管理 |

---

## 同步命令

### 从 1Password 恢复 GitHub Secret

```bash
# 示例：恢复 VAULT_POSTGRES_PASSWORD
gh secret set VAULT_POSTGRES_PASSWORD \
  --body "$(op item get 'PostgreSQL (Platform)' --vault my_cloud --fields VAULT_POSTGRES_PASSWORD --reveal)"

# 示例：恢复 VPS_SSH_KEY
gh secret set VPS_SSH_KEY \
  --body "$(op item get 'VPS SSH' --vault my_cloud --fields VPS_SSH_KEY --reveal)"
```

### 批量恢复（灾难恢复）

```bash
# Cloudflare
for f in BASE_DOMAIN CLOUDFLARE_ZONE_ID INTERNAL_DOMAIN INTERNAL_ZONE_ID CLOUDFLARE_API_TOKEN; do
  gh secret set $f --body "$(op item get 'Cloudflare API' --vault my_cloud --fields $f --reveal)"
done

# R2/AWS
for f in R2_BUCKET R2_ACCOUNT_ID AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY; do
  gh secret set $f --body "$(op item get 'R2 Backend (AWS)' --vault my_cloud --fields $f --reveal)"
done
```

---

## 层级认证模型

| 层级 | 认证方式 | 密钥来源 |
|------|----------|----------|
| **L1 Bootstrap** | 根密钥 (SSH + Vault Root Token) | 1Password 直接 |
| **L2 Platform** | 根密钥 + SSO (Casdoor OIDC) | GitHub Secrets → TF |
| **L3 Data** | Vault + SSO | Vault KV |
| **L4 Apps** | Vault + SSO | Vault 动态凭据 |

详见 [auth.md](auth.md)

---

## 实施状态

| 组件 | 状态 |
|------|------|
| 1Password SSOT | ✅ 9 项目，20+ 字段 |
| GitHub Secrets | ✅ 20 secrets |
| 1P → GH 同步 | ✅ VAULT_POSTGRES_PASSWORD 已同步 |
| CI Auto-unseal | ✅ 已实现 |
| Casdoor init_data.json | ✅ 正确挂载到 /init_data.json |

## Vault-first 密钥策略

- **1Password 仅存根密钥**（Atlantis 登录、Vault root token、Casdoor 管理密码），作为离线恢复源，不再做日常运维依赖。
- **Vault 作为主库**：所有运行时凭据、Casdoor client secret、Webhook Token、Terraform `random_password` 等都优先写入 Vault，再由 Agent 注入或同步到 CI 环境，避免在 1Password 里频繁复制粘贴。
- **Fallback 设计**：当需要同时保留 1Password 与 Vault 副本时，Vault 为 SSOT、1Password 仅做 backup（“Vault-first, 1Password fallback”），确保可以实现“1Password 0 依赖”或将全部凭据迁移到 Vault 的两条路径。
