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

### Usage

```bash
terraform apply -target="module.platform"
```

### Access

- **Infisical**: `https://i-secrets.<base_domain>` (GitHub OAuth)
- **Dashboard**: `https://i-kdashboard.<base_domain>` (token auth via Kong proxy)

### Known Issues

- **Infisical Helm chart ingress bug**: The `infisical-standalone` chart doesn't set `host` in ingress rules correctly, causing it to match all domains. We work around this by disabling the chart's ingress and creating our own `kubernetes_ingress_v1` resource.
- **PostgreSQL storage**: Uses StorageClass `local-path-retain` (path `/data/local-path-provisioner`, `ReclaimPolicy=Retain`). PVC deletion will leave PV/data behind; manual cleanup required.

### Disaster Recovery

- **Lost Infisical Data**: Re-apply helm chart. PG data persists in PVC.
- **Lost Admin Access**: Rotate `random_password` in Terraform state.

---
*Last updated: 2025-12-09*
