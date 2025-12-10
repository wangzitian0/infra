# 2.platform (Platform Layer / Layer 2)

**Scope**:
- **Secrets**: Vault (PostgreSQL storage backend, Agent Injector)
- **Platform DB**: PostgreSQL (for Vault)
- **Dashboard**: Kubernetes Dashboard (cluster web UI)
- **PaaS**: Kubero (Heroku-like GitOps)
- **Namespaces**: `platform` (main), `kubero`, `kubero-operator-system`

## Architecture

This layer provides platform-level components that support application deployment.
Depends on L1 (bootstrap) for K8s cluster availability.

### Components

| File | Component | Purpose |
|------|-----------|---------|
| `1.postgres.tf` | Platform PostgreSQL | Database for Vault (namespace: `platform`) |
| `2.secret.tf` | Vault | Secrets management (PostgreSQL backend + injector) |
| `3.dashboard.tf` | K8s Dashboard | Cluster management web UI via Ingress |
| `4.kubero.tf` | Kubero | GitOps PaaS (uses kubectl provider for CRD deployment) |

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

- **Vault**: `https://secrets.<internal_domain>` (HTTPS via cert-manager; manual init/unseal required)
- **Dashboard**: `https://kdashboard.<internal_domain>` (HTTPS via cert-manager; token auth)

### Known Issues

- **Vault init/unseal**: Manual init/unseal required after deploy; store keys outside Terraform.
- **PostgreSQL storage**: Uses `local-path-retain` StorageClass (reclaimPolicy=Retain) to keep PV data after PVC deletion.
- **PostgreSQL upgrades**: `helm_release.postgresql` uses `force_update=true` to allow spec changes (e.g., auth tweaks). Expect pod recreation/downtime during upgrades.

### Disaster Recovery

- **Lost Vault Pods**: Re-apply helm chart; PostgreSQL data persists in PVC (`/data/local-path-provisioner`). Re-unseal using stored keys.
- **Lost Admin Access**: Recover using stored root token/unseal keys.

---
*Last updated: 2025-12-10*
