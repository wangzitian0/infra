# 2.platform (Platform Layer / Layer 2)

<!-- Smoke: validate infra-flash per-commit comment stream (post-merge) -->

**Scope**:
- **Secrets**: Vault (PostgreSQL storage backend, Agent Injector)
- **Platform DB**: PostgreSQL (for Vault)
- **Dashboard**: Kubernetes Dashboard (cluster web UI)
- **SSO**: Casdoor (OIDC provider for L2+ services)
- **Namespaces**: `platform` (main), `kubero-operator-system` (Operator only)

## Architecture

This layer provides platform-level components that support application deployment.
Depends on L1 (bootstrap) for K8s cluster availability.

### Components

| File | Component | Purpose |
|------|-----------|---------|
| `2.secret.tf` | Vault | Secrets management (PostgreSQL backend + injector) |
| `3.dashboard.tf` | K8s Dashboard | Cluster management web UI via Ingress |
| `5.casdoor.tf` | Casdoor SSO | Helm release + bootstrap init_data (org, admin, builtin-app only) |
| `6.vault-database.tf` | Vault Database | Dynamic PostgreSQL credentials for L3 (roles: app-readonly, app-readwrite) |
| `90.provider_restapi.tf` | RestAPI Provider | Casdoor REST API provider (M2M credentials via casdoor-builtin-app) |
| `90.casdoor-apps.tf` | Casdoor Apps | OIDC applications & Providers (GitHub) via `restapi_object` resources |
| `91.vault-auth.tf` | Vault OIDC Auth | Vault OIDC backend connected to Casdoor |
| `91.vault-auth-kubernetes.tf` | Vault K8s Auth | Kubernetes authentication backend for pod identity |
| `92.vault-kubero.tf` | Kubero Vault | Vault KV secrets (session/webhook/OIDC), policies, and roles for Kubero |
| `92.portal-auth.tf` | Portal SSO Gate | Optional Casdoor-backed OAuth2-Proxy + Traefik middleware |
| `99.checks.tf` | SSO Validation | Whitebox checks for OIDC discovery, Casdoor health, and Portal auth readiness |

### Secrets Strategy

- **Bootstrap (L1)**: GitHub Secrets -> Terraform vars (VPS access, R2, Cloudflare)
- **Runtime (L2+)**: Vault Agent Injector (planned: map secrets to workloads)

### Deployment & Configuration

This layer supports both **Atlantis (CI)** and **Standalone/Local** execution.

- **Backend state**: Stored in Cloudflare R2 (`backend.tf`)
- **Pipeline Feedback**: All Plan/Apply actions are synchronized to the **`infra-flash` Dashboard** in the PR.
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
- **Casdoor**: `https://sso.<internal_domain>` (e.g., `sso.zitian.party`) - Unified SSO

### Authentication Model

L2 services use **app-level authentication** (no unified ingress gate):

| Service | Auth Method | Notes |
|---------|-------------|-------|
| **Vault** | Token / OIDC | Manual init/unseal required; OIDC login requires manually entering role: `reader` (controlled by `enable_casdoor_oidc`) |
| **Dashboard** | Token | Get token: `kubectl get secret dashboard-admin-token -n platform -o jsonpath='{.data.token}' \| base64 -d` |
| **Casdoor** | Admin password | SSO provider itself; admin password from `terraform output -raw casdoor_admin_password` |
| **Portal SSO Gate** | Casdoor OIDC via OAuth2-Proxy | Optional：`enable_portal_sso_gate=true` 后为 **无 OIDC 门户**（如 Dashboard）打开入口 |

Casdoor OIDC apps are configured to show a unified login page with **Password + GitHub** (see `2.platform/90.casdoor-apps.tf`).

See- [platform.network.md](../docs/ssot/platform.network.md) - Domain rules and routing
- [ops.pipeline.md](../docs/ssot/ops.pipeline.md) - PR -> Plan/Apply workflow (Atlantis + infra-flash)
- [platform.auth.md](../docs/ssot/platform.auth.md) - Authentication strategy (Casdoor + Vault)

## Troubleshooting

### Atlantis Lock Failure
If Atlantis fails to delete PR locks, it might be due to a workspace lock. Use `atlantis unlock` command in the PR.
Portal SSO Gate Rollout（前置变量 → 自动化 → 事后验证/切流）
1. **前置准备**：先部署 Casdoor（`enable_casdoor_oidc=false` / `enable_portal_sso_gate=false`），确认 `sso.<internal_domain>` 可用。Portal Gate 客户端可选手动创建并填入 `casdoor_portal_client_id/secret`；若留空，开关开启时 Terraform 会自动生成 secret。
2. **原生 OIDC**：设置 `enable_casdoor_oidc=true` 并 apply，Terraform 自动生成/写入 Casdoor OIDC 应用（Vault/Kubero/预留 Dashboard），Vault OIDC 开启但 **不挂 forwardAuth**。
3. **Portal Gate**：仅对无 OIDC 门户（如 Dashboard）设置 `enable_portal_sso_gate=true` 并 apply，Ingress 挂 Traefik ForwardAuth（OAuth2-Proxy→Casdoor）。
4. **事后验证/切流**：验证 `kdashboard` 302 → Casdoor 登录链路；Vault/Kubero 应保持 **原生 OIDC 直连**。若异常可立即将开关关回 `false` 并重跑 apply，避免锁死。

### Domain Configuration

The `internal_domain` variable controls all platform service hostnames:
- Default: `zitian.party`
- Override via `TF_VAR_internal_domain` in Atlantis environment

Note: `base_domain` (`truealpha.club`) is for business/production apps, `internal_domain` is for platform infrastructure.

### Known Issues

- **Vault init/unseal**: Manual init/unseal required after deploy; store keys outside Terraform.
- **PostgreSQL storage**: Uses `local-path-retain` StorageClass (reclaimPolicy=Retain) to keep PV data after PVC deletion. See [ops.storage.md](../docs/ssot/ops.storage.md).
- **PostgreSQL upgrades**: `helm_release.postgresql` uses `force_update=true` to allow spec changes (e.g., auth tweaks). Expect pod recreation/downtime during upgrades.
- **Namespace ownership**: `platform` namespace is created in L1 (`1.bootstrap/5.platform_pg.tf`), not L2. The Atlantis workflow removes stale namespace refs from L2 state automatically.
- **Casdoor login bug**: Requires `copyrequestbody = true` in `app.conf` to fix "unexpected end of JSON input" error. See [#3224](https://github.com/casdoor/casdoor/issues/3224).
- **Casdoor init_data**: Only loads on first startup. If `casdoor_admin_password` changes, manually update `casdoor-builtin-app` clientSecret via Casdoor UI or API. For disaster recovery (fresh install), init_data re-creates all bootstrap entities.
- **Casdoor login white screen**: If app `signupItems` is `null`, the login page crashes in `AgreementModal`. Keep `signupItems=[]` in `2.platform/90.casdoor-apps.tf`.
- **Casdoor token format**: v1.570.0 requires explicit `tokenFormat`; empty causes `unknown application TokenFormat` during login. Set `tokenFormat="JWT"` in `2.platform/90.casdoor-apps.tf`.
- **Casdoor token TTL**: If `expireInHours/refreshExpireInHours` are `0`, OAuth2-Proxy will reject with `id_token is expired`. Set both to `168` in `2.platform/90.casdoor-apps.tf`.
- **Casdoor REST API updates**: `restapi_object` updates default to PUT, but `update-application`/`update-provider` require POST and `?id=admin/{id}`. Set `update_method = "POST"` and include the id query to avoid 404/500s.


### Disaster Recovery

- **Lost Vault Pods**: Re-apply helm chart; PostgreSQL data persists in PVC (`/data/local-path-provisioner`). Re-unseal using stored keys.
- **Lost Admin Access**: Recover using stored root token/unseal keys.

---

### Portal SSO Gate Deployment

**Status**: Controlled by `enable_portal_sso_gate`

To deploy Portal SSO Gate for non-OIDC portals (e.g., Dashboard):
1. This PR triggers Atlantis to run `terraform plan -d 2.platform`
2. Review the plan (should show portal-auth resources and Ingress middleware annotations)
3. Comment `atlantis apply -d 2.platform` to deploy
4. Verify SSO login at:
   - https://kdashboard.zitian.party (Dashboard)

---
*Last updated: 2025-12-20 (Vault SSOT per Issue #301; Portal Gate/OIDC switches decoupled for native OIDC flows)*

---

## TODO: 开发者体验改进

### 1. 平台服务访问信息不够突出
**问题**: "Access" 章节列出了各个服务的 URL，但缺少开发者最关心的信息：如何获取访问凭据？

**建议**:
- [ ] 重新组织 "## Access" 章节，按服务提供完整的访问指南
- [ ] 每个服务应包括：
  - 访问 URL
  - 登录凭据获取方式（命令 + 示例输出）
  - 首次登录后需要做什么（如 Vault 的 unseal）
  - 常见访问问题及解决方案
- [ ] 为开发者最常用的服务（Vault、Casdoor、Dashboard）提供"快速访问卡片"

**受影响角色**: 应用开发者（访问平台服务）

### 2. Authentication Model 章节需要开发者视角
**问题**: Authentication Model 表格面向运维者，开发者看不懂"Token / OIDC"、"Manually enter role: reader"这些概念。

**建议**:
- [ ] 在 Authentication Model 表格前增加"开发者常见场景"小节
- [ ] 按场景说明：
  - **场景 1: 我想查看应用的密钥** → 访问 Vault UI，使用 OIDC 登录
  - **场景 2: 我想查看 K8s 资源** → 访问 Dashboard，获取 token
  - **场景 3: 我想管理 SSO 应用** → 访问 Casdoor，使用 admin 密码
- [ ] 每个场景提供完整的操作步骤

**受影响角色**: 应用开发者（理解认证模型）

### 3. Troubleshooting 缺少开发者常见问题
**问题**: 当前 Troubleshooting 主要是基础设施问题（Namespace stuck、Secret not found），缺少开发者在使用平台服务时遇到的问题。

**建议**:
- [ ] 新增 "## Developer FAQ" 章节
- [ ] 包含常见问题：
  - Q: 为什么我在 Vault UI 登录后看不到我的密钥？
    A: 检查 Policy 权限，确认 Role 绑定正确
  - Q: 如何在本地开发环境访问 Vault？
    A: 使用 kubectl port-forward 或配置 VPN
  - Q: Casdoor 应用配置修改后不生效？
    A: 检查 Terraform state，可能需要重新 apply
  - Q: 如何为新应用创建 Vault Role？
    A: 参考 `92.vault-kubero.tf` 示例，在 L2 添加配置

**受影响角色**: 应用开发者（故障排查）
