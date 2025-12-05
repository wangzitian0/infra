# 1.nodep (Bootstrap / Layer 1)

**Scope**:
- Zero-Dependency Infrastructure.
- VPS provisioning via Terraform + SSH.
- **k3s Cluster Bootstrap**.

## Deployment (Phase 0.x)

This layer bootstraps the Kubernetes runtime on a raw VPS.

### 1. Requirements (GitHub Secrets)
These are used by the CI/CD pipeline to access the VPS and store state.
- `VPS_HOST`: IP or domain.
- `VPS_SSH_KEY`: Private key (root access).
- `VPS_USER`: `root` (default).
- `R2_BUCKET` / `R2_ACCOUNT_ID`: State Storage.
- `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`: State Credentials.

### 2. Execution
```bash
terraform init -backend-config=...
terraform apply -target="module.nodep" -var-file="envs/staging.tfvars"
```
**Effect**:
- Installs k3s single-node cluster.
- Generates `kubeconfig` (output).
- Prepares node for subsequent layers.
