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
| `3.dashboard.tf` | K8s Dashboard | Cluster management web UI (NodePort 30443) |

### Secrets Strategy

- **Bootstrap (L1)**: GitHub Secrets → Terraform vars (VPS access, R2, Cloudflare)
- **Runtime (L2+)**: Infisical → K8s Secrets (application credentials)

### Usage

```bash
terraform apply -target="module.platform"
```

### Access

- **Infisical**: `https://i-infisical.<base_domain>` (GitHub OAuth)
- **Dashboard**: `https://<VPS_IP>:30443` (token auth)

### Disaster Recovery

- **Lost Infisical Data**: Re-apply helm chart. PG data persists in PVC.
- **Lost Admin Access**: Rotate `random_password` in Terraform state.

---
*Last updated: 2025-12-08*
