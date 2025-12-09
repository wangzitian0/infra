# 1.bootstrap (L1 Bootstrap Layer)

**Scope**: Zero-dependency infrastructure bootstrap.

- **K3s Cluster**: VPS provisioning via SSH
- **Atlantis CI**: GitOps workflow engine
- **DNS/Cert**: Cloudflare DNS + Let's Encrypt
- **Namespace**: `kube-system`, `bootstrap` (L1 layer)

## Architecture

This layer runs **first** and has no dependencies on other layers.
Managed by **GitHub Actions only** (not Atlantis).

### Components

| File | Component | Purpose |
|------|-----------|---------|
| `1.k3s.tf` | K3s Cluster | SSH-based VPS bootstrap |
| `2.atlantis.tf` | Atlantis | GitOps CI/CD for L2-L4 |
| `3.dns_and_cert.tf` | DNS + Certs | Cloudflare + cert-manager |

## Key Files

| File | Purpose |
|------|---------|
| `backend.tf` | R2/S3 state backend config |
| `providers.tf` | Provider definitions |
| `variables.tf` | All L1 variables |
| `outputs.tf` | Kubeconfig + R2 credentials for L2 |

## Bootstrap Command

```bash
# First-time setup (run locally with credentials)
cd 1.bootstrap
terraform init
terraform apply
```

## Outputs for L2

| Output | Description |
|--------|-------------|
| `kubeconfig` | Cluster access (sensitive) |
| `r2_bucket` | State bucket name |
| `r2_account_id` | R2 endpoint |

---
*Last updated: 2025-12-09*
