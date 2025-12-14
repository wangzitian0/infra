# 2.platform (Platform Layer / Layer 2)

**Scope**:
- **Secrets**: Vault (PostgreSQL storage backend, Agent Injector)
- **Platform DB**: PostgreSQL (for Vault)
- **Dashboard**: Kubernetes Dashboard (cluster web UI)
- **SSO**: Casdoor (OIDC provider for L2+ services)
- **PaaS**: Kubero (Heroku-like GitOps)
- **Namespaces**: `platform` (main), `kubero`, `kubero-operator-system`

## Architecture

This layer provides platform-level components that support application deployment.
Depends on L1 (bootstrap) for K8s cluster availability.

### Components

| File | Component | Purpose |
|------|-----------|---------|
| `1.portal-auth.tf` | Portal SSO Gate | Optional Casdoor-backed OAuth2-Proxy + Traefik middleware |
| `2.secret.tf` | Vault | Secrets management (PostgreSQL backend + injector) |
| `3.dashboard.tf` | K8s Dashboard | Cluster management web UI via Ingress |
| `4.kubero.tf` | Kubero | GitOps PaaS (uses kubectl provider for CRD deployment) |
| `5.casdoor.tf` | Casdoor SSO | Unified SSO (OIDC provider, uses REST API for declarative application management) |
| `6.vault-database.tf` | Vault Database | Dynamic PostgreSQL credentials for L3 (roles: app-readonly, app-readwrite) |
| `99.one-auth.tf` | One-Auth Gate | SSO gate switch and preconditions (controlled by `enable_one_auth`) |

### Secrets Strategy

- **Bootstrap (L1)**: GitHub Secrets -> Terraform vars (VPS access, R2, Cloudflare)
- **Runtime (L2+)**: Vault Agent Injector (planned: map secrets to workloads)

### Deployment & Configuration

This layer supports both **Atlantis (CI)** and **Standalone/Local** execution.

- **Backend state**: Stored in Cloudflare R2 (`backend.tf`)
- **Providers**: Auto-configured for both local kubeconfig and in-cluster ServiceAccount (`providers.tf`)
- **Variables**: Defaults provided in `variables.tf`; Atlantis injects environment-specific values via `TF_VAR_*` env vars.

```bash
# Standalone usage (requires local kubeconfig)
cd 2.platform
terraform init -backend-config="bucket=$R2_BUCKET" ...
terraform apply
```

### Access

- **Vault**: `https://secrets.<internal_domain>` (e.g., `secrets.zitian.party`) - HTTPS via cert-manager; manual init/unseal required
- **Dashboard**: `https://kdashboard.<internal_domain>` (e.g., `kdashboard.zitian.party`) - HTTPS via cert-manager
- **Kubero**: `https://kcloud.<internal_domain>` (e.g., `kcloud.zitian.party`) - GitOps PaaS UI
- **Casdoor**: `https://sso.<internal_domain>` (e.g., `sso.zitian.party`) - Unified SSO

### Authentication Model

L2 services use **app-level authentication** (no unified ingress gate):

| Service | Auth Method | Notes |
|---------|-------------|-------|
| **Vault** | Token / OIDC (planned) | Manual init/unseal required; OIDC via Casdoor (future) |
| **Dashboard** | Token | Get token: `kubectl get secret dashboard-admin-token -n platform -o jsonpath='{.data.token}' \| base64 -d` |
| **Kubero** | Session / OAuth2 (planned) | OAuth2 via Casdoor (future) |
| **Casdoor** | Admin password | SSO provider itself; admin password from `terraform output -raw casdoor_admin_password` |
| **Portal SSO Gate** | Casdoor OIDC via OAuth2-Proxy | Optional：`enable_portal_sso_gate=true` 后为 Vault/Dashboard/Kubero 打开统一入口 |

See [docs/ssot/auth.md](../docs/ssot/auth.md) for the full authentication architecture.

#### Portal SSO Gate Rollout（前置变量 → 自动化 → 事后验证/切流）
1. **前置填写**：保持 `enable_portal_sso_gate=false` 部署 Casdoor。Portal Gate 客户端可选手动创建并填入 `casdoor_portal_client_id/secret`；若留空，开关开启时 Terraform 会自动生成 secret。
2. **自动化执行**：在 2.platform 目录设置变量后，`terraform init && terraform apply`。开关置 `true` 时，Terraform 自动生成/写入 Casdoor 应用（Portal/Vault/Dashboard/Kubero），Ingress 自动挂 Traefik ForwardAuth（OAuth2-Proxy→Casdoor）。
3. **事后验证/切流**：依次验证 `secrets/kdashboard/kcloud` 302 → Casdoor 登录链路，若异常可立即将开关关回 `false` 并重跑 apply，避免锁死。

#### ForwardAuth 端点配置

Portal SSO Gate 使用 **根路径 `/`** 作为 ForwardAuth 端点（而非 `/oauth2/auth` 或 `/oauth2/start`）：

- **配置**：`upstream=static://202` + `reverse-proxy=true`
- **行为**：已认证返回 202，未认证返回 302 重定向到 Casdoor
- **优势**：无需 errors middleware，自动处理登录重定向
- **参考**：https://farcaller.net/2024/oauth-and-traefik-how-to-protect-your-endpoints/

#### OIDC Secrets 灾难恢复

REST API 管理模式下，OIDC client secrets 存储在 Terraform state 和 Casdoor DB 中。为确保一致性：

1. **建议做法**：首次部署后，将自动生成的 OIDC client secrets 保存到 1Password
2. **支持变量**：
   - `TF_VAR_casdoor_vault_oidc_client_secret`
   - `TF_VAR_casdoor_dashboard_oidc_client_secret`
   - `TF_VAR_casdoor_kubero_oidc_client_secret`
3. **灾难场景**：如果 Terraform state 丢失但 Casdoor DB 保留，从 1Password 恢复这些 secrets 到 GitHub Secrets / TF 变量

详见 [docs/ssot/secrets.md](../docs/ssot/secrets.md#casdoor-oidc-secrets-灾难恢复策略)

### Domain Configuration

The `internal_domain` variable controls all platform service hostnames:
- Default: `zitian.party`
- Override via `TF_VAR_internal_domain` in Atlantis environment

Note: `base_domain` (`truealpha.club`) is for business/production apps, `internal_domain` is for platform infrastructure.

### Known Issues

- **Vault init/unseal**: Manual init/unseal required after deploy; store keys outside Terraform.
- **PostgreSQL storage**: Uses `local-path-retain` StorageClass (reclaimPolicy=Retain) to keep PV data after PVC deletion.
- **PostgreSQL upgrades**: `helm_release.postgresql` uses `force_update=true` to allow spec changes (e.g., auth tweaks). Expect pod recreation/downtime during upgrades.
- **Namespace ownership**: `platform` namespace is created in L1 (`1.bootstrap/5.platform_pg.tf`), not L2. The Atlantis workflow removes stale namespace refs from L2 state automatically.
- **Casdoor login bug**: Requires `copyrequestbody = true` in `app.conf` to fix "unexpected end of JSON input" error. See [#3224](https://github.com/casdoor/casdoor/issues/3224).
- **Casdoor REST API**: Applications/providers managed via `restapi` provider (not `casdoor/casdoor` which requires Casdoor running during plan).
- **Kubero UI image pin**: Prefer pinning `kubero_ui_image_tag` to a fixed version and keep pull policy `IfNotPresent` for reproducible deploys.

### Disaster Recovery

- **Lost Vault Pods**: Re-apply helm chart; PostgreSQL data persists in PVC (`/data/local-path-provisioner`). Re-unseal using stored keys.
- **Lost Admin Access**: Recover using stored root token/unseal keys.

---
*Last updated: 2025-12-15*
