# 认证与授权 SSOT

> **一句话**：L1 使用根密钥，L2 支持根密钥+SSO 双认证，L3/L4 完全走 Vault+SSO。

## 分层认证架构

```mermaid
graph TD
    subgraph "认证方式"
        ROOT[根密钥<br/>1Password]
        SSO[Casdoor SSO<br/>GitHub/Google OAuth]
        VAULT_AUTH[Vault Auth<br/>Token/OIDC]
    end

    subgraph "L1 Bootstrap"
        L1_ATLANTIS[Atlantis]
        L1_K3S[K3s API]
    end

    subgraph "L2 Platform"
        L2_VAULT[Vault UI]
        L2_DASH[K8s Dashboard]
        L2_CASDOOR[Casdoor]
    end

    subgraph "L3 Data"
        L3_PG[PostgreSQL]
        L3_REDIS[Redis]
    end

    subgraph "L4 Apps"
        L4_APPS[应用]
    end

    ROOT -->|Basic Auth| L1_ATLANTIS
    ROOT -->|Token| L1_K3S
    
    ROOT -->|Root Token| L2_VAULT
    SSO -->|OIDC| L2_VAULT
    SSO -->|OIDC| L2_DASH
    SSO -->|管理| L2_CASDOOR

    VAULT_AUTH --> L3_PG
    SSO --> L3_PG
    
    VAULT_AUTH --> L4_APPS
    SSO --> L4_APPS
```

---

## 层级认证策略

| 层级 | 服务 | 认证方式 | 说明 |
|------|------|----------|------|
| **L1** | Atlantis | 根密钥 (Basic Auth) | 不能依赖 L2 SSO (循环依赖) |
| **L1** | K3s API | 根密钥 (Token) | 系统级 |
| **L2** | Vault | 根密钥 (Root Token) + SSO (OIDC) | **双认证** - 灾难恢复 |
| **L2** | Dashboard | 根密钥 + SSO (OIDC) | **双认证** - 运维需要 |
| **L2** | Casdoor | 根密钥 (admin 密码) | SSO 入口本身 |
| **L3** | PostgreSQL | Vault 动态凭据 | 业务 DB |
| **L3** | Redis | Vault 动态凭据 | 业务缓存 |
| **L4** | Apps | Vault + SSO | 业务层完全依赖平台认证 |

---

## 门户级统一 SSO（Casdoor）

L2 门户级服务通过 **Portal SSO Gate**（OAuth2-Proxy + Casdoor OIDC）实现统一登录，减少各自的 Token 配置并提升运维一致性。

| 服务 | 域名 | SSO 形态 | 当前状态 |
|------|------|-----------|----------|
| **Portal SSO Gate** | `https://auth.<internal_domain>` | OAuth2-Proxy → Casdoor OIDC | ✅ 已部署 |
| Vault UI | `https://secrets.<internal_domain>` | Traefik ForwardAuth → Portal Gate | ✅ SSO Gate 保护 |
| Kubernetes Dashboard | `https://kdashboard.<internal_domain>` | Traefik ForwardAuth → Portal Gate | ✅ SSO Gate 保护 |
| Kubero UI | `https://kcloud.<internal_domain>` | Traefik ForwardAuth → Portal Gate | ✅ SSO Gate 保护 |
| Atlantis Web | `https://atlantis.<internal_domain>` | Basic Auth（继续当前机制） | ✅ 保持手动管理 |

### 实施路径

1. **前置填写**：保持 `enable_portal_sso_gate=false` 部署 Casdoor。门户客户端可手动创建并填入 `casdoor_portal_client_id/secret`；若留空，开关开启时 Terraform 自动生成 secret 并写入 Casdoor `init_data`（同时生成 Vault/Dashboard/Kubero 客户端）。
2. **自动化执行**：在 2.platform 设置变量后 `terraform init && terraform apply`，开关置 `true` 时 Ingress 自动挂 Traefik ForwardAuth（OAuth2-Proxy→Casdoor），相关 Casdoor 应用与凭据自动创建。
3. **事后验证/切流**：依次验证 `secrets/kdashboard/kcloud` 登录链路。若异常可关回 `false` 并重跑 apply，避免锁死。随后按需启用 Vault/Dashboard/Kubero 的 OIDC/OAuth 回调。

这一部分的更多细节参考 BRN-008 中的“场景 5：所有 Portal 走 Casdoor”。

---

## 根密钥管理

| 服务 | 根密钥位置 | GitHub Secret | 用途 |
|------|-----------|---------------|------|
| Atlantis | 1Password `Atlantis` | `ATLANTIS_WEB_PASSWORD` | Web 登录 |
| K3s | kubeconfig 文件 | *(CI 生成)* | kubectl |
| Vault | 1Password `Vault (zitian.party)` | `VAULT_UNSEAL_KEY` | 解封/Root 登录 |
| Casdoor | 1Password `Casdoor Admin` | *(代码中)* | 管理登录 |

---

## SSO (Casdoor) 配置

### Identity Providers

| Provider | 用途 | 状态 |
|----------|------|------|
| GitHub | 开发者登录 | ✅ 已配置 (`TF_VAR_github_oauth_client_id/secret`) |
| Google | 备用登录 | ⏳ 待配置（可选） |

### OIDC Clients (Casdoor REST API 管理)

| 应用 | Client ID | Redirect URI | 状态 |
|------|-----------|--------------|------|
| Portal Gate | `portal-gate` | `https://auth.<internal_domain>/oauth2/callback` | ✅ REST API 管理 |
| Vault | `vault-oidc` | `https://secrets.<internal_domain>/ui/vault/auth/oidc/oidc/callback` | ✅ REST API 管理 |
| Dashboard | `dashboard-oidc` | `https://kdashboard.<internal_domain>/oauth2/callback` | ✅ REST API 管理 |
| Kubero | `kubero-oidc` | `https://kcloud.<internal_domain>/auth/callback` | ✅ REST API 管理 |

---

## 认证凭据存储对照

| 凭据类型 | 存储位置 | 访问方式 |
|----------|----------|----------|
| 根密钥 | 1Password | `op` CLI 本地 |
| CI 密钥 | GitHub Secrets | `${{ secrets.* }}` |
| 运行时密钥 | Vault | Kubernetes SA |
| 用户凭据 | Casdoor DB | OIDC Token |

---

## 密钥策略（1Password Zero 依赖 / Vault-first）

- **目标一：1Password 仅存储根密钥**（Atlantis 管理密码、Vault Root Token、Casdoor Admin 密码等），作为离线恢复点，日常操作尽量不直接依赖 `op`。
- **目标二：其他凭据均由 Vault/Terraform 生成、动态注入或同步到 Vault，Casdoor client secret、Webhook Token、业务 token 等都有 Vault 副本，保持“Vault-first”。
- 若某密钥必须同时存于 1Password 与 Vault，则让 Vault 成为 SSOT，1Password 仅做备份（“Vault-first, 1Password fallback”），明确区分“1Password 0 依赖”和“Vault 作为自动源”两条路径。

---

## 实施状态

| 组件 | 状态 |
|------|------|
| Casdoor 部署 | ✅ 已部署 (`sso.zitian.party`) |
| Portal SSO Gate | ✅ OAuth2-Proxy 已部署 (`auth.zitian.party`) |
| GitHub OAuth | ✅ Casdoor Provider 已配置 |
| Vault SSO Gate | ✅ Traefik ForwardAuth → Portal Gate |
| Dashboard SSO Gate | ✅ Traefik ForwardAuth → Portal Gate |
| Kubero SSO Gate | ✅ Traefik ForwardAuth → Portal Gate |
| Atlantis | ✅ Basic Auth（不走 SSO，避免循环依赖） |

---

## 相关文件

- [secrets.md](secrets.md) - 密钥管理 SSOT
- [5.casdoor.tf](../../2.platform/5.casdoor.tf) - Casdoor 部署 (Helm + REST API 管理)
- [2.secret.tf](../../2.platform/2.secret.tf) - Vault 配置

---

## Casdoor REST API 管理

### 为什么使用 REST API？

`casdoor/casdoor` Terraform Provider 要求 Casdoor **在 `terraform plan` 时已经运行**。
这导致首次部署时出现鸡生蛋问题：无法在 Casdoor 部署前 plan。

**解决方案**：使用 `Mastercard/restapi` Provider 调用 Casdoor 的 REST API：
- Provider 只在 `terraform apply` 时连接（非 plan）
- `/api/add-provider` - 创建 OAuth Provider
- `/api/add-application` - 创建应用
- `/api/update-application` - 更新应用
- `/api/delete-application` - 删除应用

### 认证方式

Casdoor API 使用 `clientId` + `clientSecret` 作为 query 参数进行认证：
- `clientId`: `admin`（内置应用）
- `clientSecret`: 与 `casdoor_admin_password` 相同

### 管理的资源

| 资源类型 | 名称 | 用途 |
|----------|------|------|
| Provider | `provider_github` | GitHub OAuth 登录 |
| Application | `portal-gate` | OAuth2-Proxy 统一入口 |
| Application | `vault-oidc` | Vault OIDC 登录 |
| Application | `dashboard-oidc` | K8s Dashboard SSO |
| Application | `kubero-oidc` | Kubero OAuth2 登录 |

所有应用都带有 `terraform-managed` 标签，便于区分手动创建的应用。
