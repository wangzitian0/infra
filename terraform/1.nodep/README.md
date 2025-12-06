# 1.nodep (Bootstrap / Layer 1)

**Scope**:
- Zero-Dependency Infrastructure.
- VPS provisioning via Terraform + SSH.
- **k3s Cluster Bootstrap**.
- **Atlantis CI/CD** (Terraform PR automation).

## Components

| File | Purpose |
|------|---------|
| `1.k3s.tf` | K3s single-node cluster bootstrap |
| `2.atlantis.tf` | Atlantis Helm release for Terraform CI/CD |

## Deployment

### 1. Requirements (GitHub Secrets)
These are used by the CI/CD pipeline to access the VPS and store state.
- `VPS_HOST`: IP or domain.
- `VPS_SSH_KEY`: Private key (root access).
- `VPS_USER`: `root` (default).
- `R2_BUCKET` / `R2_ACCOUNT_ID`: State Storage.
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`: State Credentials.
- `GITHUB_TOKEN`: PAT for Atlantis GitHub integration.
- `ATLANTIS_WEBHOOK_SECRET`: Webhook verification secret.

### 2. Execution
```bash
terraform init -backend-config=...
terraform apply -target="module.nodep" -var-file="envs/staging.tfvars"
```

**Effect**:
- Installs k3s single-node cluster.
- Deploys Atlantis for Terraform CI/CD.
- Generates `kubeconfig` (output).
- Prepares node for subsequent layers.
