# 2.platform (Platform Layer / Layer 2)

**Scope**:
- **Secrets**: Infisical (Self-hosted secrets management)
- **Platform DB**: PostgreSQL (for Infisical, NOT business data)
- **Dashboard**: Kubernetes Dashboard (cluster web UI)
- **PaaS**: Kubero (Heroku-like GitOps) [Planned]
- **Namespaces**: `iac`, `kubernetes-dashboard`

## Architecture

This layer provides platform-level components that support application deployment.
Depends on L1 (nodep) for K8s cluster availability.

### Components

| File | Component | Purpose |
|------|-----------|---------|
| `1.postgres.tf` | Platform PostgreSQL | Database for Infisical (namespace: `iac`) |
| `2.secret.tf` | Infisical | Secrets management with GitHub OAuth SSO |
| `3.dashboard.tf` | K8s Dashboard | Cluster management web UI via Ingress |
| `4.kubero.tf` | Kubero | GitOps PaaS (uses kubectl provider for CRD deployment) |

### Secrets Strategy

- **Bootstrap (L1)**: GitHub Secrets → Terraform vars (VPS access, R2, Cloudflare)
- **Runtime (L2+)**: Infisical → K8s Secrets (application credentials)

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

- **Infisical**: `https://i-secrets.<base_domain>` (Chart v1.7.2, GitHub OAuth)
  - *Note*: Requires manual DB migration on first install (see 0.check_now.md)
- **Dashboard**: `https://i-kdashboard.<base_domain>` (token auth via Kong proxy)

### Known Issues

- **Infisical Helm chart ingress bug**: The `infisical-standalone` chart doesn't set `host` in ingress rules correctly. We use `kubernetes_ingress_v1` resource instead.
- **Infisical Migration**: Chart v1.7.2 requires manual migration if auto-migration fails.
- **PostgreSQL storage**: Uses StorageClass `local-path-retain`. PVC deletion leaves data on disk.

### Disaster Recovery

- **Lost Infisical Data**: Re-apply helm chart. PG data persists in PVC (`/data/local-path-provisioner`).
- **Lost Admin Access**: Rotate `random_password` in Terraform state.

---
*Last updated: 2025-12-09*
