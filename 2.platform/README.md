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
| `92.vault-kubero.tf` | Kubero Vault | Vault KV secrets, policies, and roles for Kubero |
| `92.portal-auth.tf` | Portal SSO Gate | Optional Casdoor-backed OAuth2-Proxy + Traefik middleware |
| `99.checks.tf` | SSO Validation | Whitebox checks for OIDC discovery, Casdoor health, and Portal auth readiness |

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
- **Casdoor**: `https://sso.<internal_domain>` (e.g., `sso.zitian.party`) - Unified SSO

### Authentication Model

L2 services use **app-level authentication** (no unified ingress gate):

| Service | Auth Method | Notes |
|---------|-------------|-------|
| **Vault** | Token / OIDC | Manual init/unseal required; OIDC login requires manually entering role: `reader` |
| **Dashboard** | Token | Get token: `kubectl get secret dashboard-admin-token -n platform -o jsonpath='{.data.token}' \| base64 -d` |
| **Casdoor** | Admin password | SSO provider itself; admin password from `terraform output -raw casdoor_admin_password` |
| **Portal SSO Gate** | Casdoor OIDC via OAuth2-Proxy | Optional：`enable_portal_sso_gate=true` 后为 Vault/Dashboard 打开统一入口 |

Casdoor OIDC apps are configured to show a unified login page with **Password + GitHub** (see `2.platform/90.casdoor-apps.tf`).

See- [platform.network.md](../docs/ssot/platform.network.md) - Domain rules and routing
- [ops.pipeline.md](../docs/ssot/ops.pipeline.md) - PR -> Plan/Apply workflow (Atlantis + infra-flash)
- [platform.auth.md](../docs/ssot/platform.auth.md) - Authentication strategy (Casdoor + Vault)

## Troubleshooting

### Atlantis Lock Failure
If Atlantis fails to delete PR locks, it might be due to a workspace lock. Use `atlantis unlock` command in the PR.
Portal SSO Gate Rollout（前置变量 → 自动化 → 事后验证/切流）
1. **前置填写**：保持 `enable_portal_sso_gate=false` 部署 Casdoor。Portal Gate 客户端可选手动创建并填入 `casdoor_portal_client_id/secret`；若留空，开关开启时 Terraform 会自动生成 secret。
2. **自动化执行**：在 2.platform 目录设置变量后，`terraform init && terraform apply`。开关置 `true` 时，Terraform 自动生成/写入 Casdoor 应用（Portal/Vault/Dashboard），Ingress 自动挂 Traefik ForwardAuth（OAuth2-Proxy→Casdoor）。
3. **事后验证/切流**：依次验证 `secrets/kdashboard` 302 → Casdoor 登录链路，若异常可立即将开关关回 `false` 并重跑 apply，避免锁死。

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
- **Casdoor REST API updates**: `restapi_object` updates default to PUT, but `update-application`/`update-provider` require POST and `?id=admin/{id}`. Set `update_method = "POST"` and include the id query to avoid 404/500s.


### Disaster Recovery

- **Lost Vault Pods**: Re-apply helm chart; PostgreSQL data persists in PVC (`/data/local-path-provisioner`). Re-unseal using stored keys.
- **Lost Admin Access**: Recover using stored root token/unseal keys.

---

### Portal SSO Gate Deployment

**Status**: Ready to deploy (enable_portal_sso_gate=true in Atlantis config)

To deploy Portal SSO Gate for Vault/Dashboard:
1. This PR triggers Atlantis to run `terraform plan -d 2.platform`
2. Review the plan (should show portal-auth resources and Ingress middleware annotations)
3. Comment `atlantis apply -d 2.platform` to deploy
4. Verify SSO login at:
   - https://secrets.zitian.party (Vault)
   - https://kdashboard.zitian.party (Dashboard)

---
*Last updated: 2025-12-19 (Added Vault K8s auth and Kubero integration)*
