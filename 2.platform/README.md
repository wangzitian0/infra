# 2.platform (Platform Layer / Layer 2)

**Scope**:
- **Secrets**: Vault (PostgreSQL storage backend, Agent Injector)
- **Platform DB**: PostgreSQL (for Vault)
- **Dashboard**: Kubernetes Dashboard (cluster web UI)
- **OAuth**: OAuth2-Proxy (GitHub authentication gateway, conditional)
- **PaaS**: Kubero (Heroku-like GitOps)
- **Namespaces**: `platform` (main), `kubero`, `kubero-operator-system`

## Architecture

This layer provides platform-level components that support application deployment.
Depends on L1 (bootstrap) for K8s cluster availability.

### Components

| File | Component | Purpose |
|------|-----------|---------|
| `1.oauth.tf` | OAuth2-Proxy | GitHub OAuth gateway (conditional: requires `github_oauth_client_id/secret`) |
| `2.secret.tf` | Vault | Secrets management (PostgreSQL backend + injector) |
| `3.dashboard.tf` | K8s Dashboard | Cluster management web UI via Ingress |
| `4.kubero.tf` | Kubero | GitOps PaaS (uses kubectl provider for CRD deployment) |
| `5.casdoor.tf` | Casdoor SSO | Unified SSO (OIDC provider, uses `initData` for IaC initialization of org/user/app) |
| `99.one-auth.tf` | One-Auth Gate | SSO gate switch and preconditions (controlled by `enable_one_auth`) |

### Secrets Strategy

- **Bootstrap (L1)**: GitHub Secrets → Terraform vars (VPS access, R2, Cloudflare)
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
- **OAuth2-Proxy**: `https://auth.<internal_domain>` (e.g., `auth.zitian.party`) - GitHub OAuth gateway (only when enabled)
- **Kubero**: `https://kcloud.<internal_domain>` (e.g., `kcloud.zitian.party`) - GitOps PaaS UI
- **Casdoor**: `https://sso.<internal_domain>` (e.g., `sso.zitian.party`) - Unified SSO (when enabled)

### Dashboard Authentication

Kubernetes Dashboard v7 has two authentication layers:

1. **Access Control (One-Auth SSO Gate)**: When `enable_one_auth=true`, only GitHub-authenticated users can reach protected L2 services (Traefik middleware backed by OAuth2-Proxy)
2. **API Authentication (Token)**: Dashboard still requires a token to authenticate Kubernetes API calls

**To login:**
1. Navigate to `https://kdashboard.<internal_domain>` - you'll be gated by SSO (if enabled)
2. After OAuth, you'll see the Dashboard login page
3. Get the admin token:
   ```bash
   kubectl get secret dashboard-admin-token -n platform -o jsonpath='{.data.token}' | base64 -d
   ```
4. Paste the token and click "Sign in"

**Why two authentication layers?**
- OAuth2-Proxy controls WHO can access the dashboard (GitHub org members)
- Token controls WHAT you can do in the cluster (cluster-admin via `dashboard-admin` ServiceAccount)

### One-Auth (Two-Phase Rollout)

Terraform does **not** guarantee file order; rollout is controlled by `enable_one_auth`.

**Security notes:**
- One-Auth gates Ingress access for all L2 services (Vault/Dashboard/Kubero/Casdoor still have their own app-level auth).
- GitHub access tokens are **not** forwarded to upstream services (only user/email headers).
- Strongly recommended: set `github_oauth_org` when enabling the gate; leaving it empty allows **any GitHub user** to pass the gate.

1) **Phase A: Deploy L2 base (no SSO gate)**
   - Set `enable_one_auth=false` (default)
   - `terraform apply`
   - Verify you can reach:
     - `https://secrets.<internal_domain>` (Vault UI loads; init/unseal is separate)
     - `https://kdashboard.<internal_domain>` (Dashboard loads)
     - `https://kcloud.<internal_domain>` (Kubero UI loads)
     - `https://sso.<internal_domain>` (Casdoor UI loads, when enabled)

2) **Phase B: Enable SSO gate**
   - Set `enable_one_auth=true`
   - `terraform apply`
   - Verify the above endpoints are now SSO-gated.

### Domain Configuration

The `internal_domain` variable controls all platform service hostnames:
- Default: `zitian.party`
- Override via `TF_VAR_internal_domain` in Atlantis environment

Note: `base_domain` (`truealpha.club`) is for business/production apps, `internal_domain` is for platform infrastructure.

### OAuth2-Proxy (Conditional)

OAuth2-Proxy is **only deployed** when both `github_oauth_client_id` and `github_oauth_client_secret` are set.

Implementation note: One-Auth uses Traefik ForwardAuth against OAuth2-Proxy `/` (not `/oauth2/auth`) so unauthenticated requests can be redirected into the OAuth flow.

**Setup (optional)**:
1. Create GitHub OAuth App: https://github.com/settings/developers
   - Homepage URL: `https://auth.<internal_domain>`
   - Callback URL: `https://auth.<internal_domain>/oauth2/callback`
2. Set `TF_VAR_github_oauth_client_id` and `TF_VAR_github_oauth_client_secret` in L1 bootstrap

When disabled:
- L2 services are accessible without the SSO gate (token/app auth only)
- Enabling `enable_one_auth` will fail prechecks

### Known Issues

- **Vault init/unseal**: Manual init/unseal required after deploy; store keys outside Terraform.
- **PostgreSQL storage**: Uses `local-path-retain` StorageClass (reclaimPolicy=Retain) to keep PV data after PVC deletion.
- **PostgreSQL upgrades**: `helm_release.postgresql` uses `force_update=true` to allow spec changes (e.g., auth tweaks). Expect pod recreation/downtime during upgrades.
- **Namespace ownership**: `platform` namespace is created in L1 (`1.bootstrap/5.platform_pg.tf`), not L2. The Atlantis workflow removes stale namespace refs from L2 state automatically.

### Disaster Recovery

- **Lost Vault Pods**: Re-apply helm chart; PostgreSQL data persists in PVC (`/data/local-path-provisioner`). Re-unseal using stored keys.
- **Lost Admin Access**: Recover using stored root token/unseal keys.
- **SSO Gate Lockout**: Set `enable_one_auth=false` and re-apply, or use `kubectl port-forward` to reach services directly (bypass Ingress).

---
*Last updated: 2025-12-13*
