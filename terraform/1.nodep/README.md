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
| `3.dns_and_cert.tf` | Cloudflare DNS, Cert Manager, ClusterIssuer |
| `network.md` | Domain naming conventions (SSOT) |

## Deployment

### 1. Requirements (Terraform Variables → Atlantis Runtime)

These secrets are passed as Terraform variables and injected into Atlantis at runtime:

| Variable | Purpose | Atlantis Env |
|----------|---------|--------------|
| `vps_host` | VPS IP for SSH | `VPS_HOST` |
| `ssh_private_key` | Root SSH key | `VPS_SSH_KEY` |
| `aws_access_key_id` | R2 credentials | `AWS_ACCESS_KEY_ID` |
| `aws_secret_access_key` | R2 credentials | `AWS_SECRET_ACCESS_KEY` |
| `r2_bucket` | State backend | `R2_BUCKET` |
| `r2_account_id` | R2 endpoint | `R2_ACCOUNT_ID` |
| `github_token` | GitHub PAT | (Helm github.token) |
| `atlantis_webhook_secret` | Webhook verify | (Helm github.secret) |
| `cloudflare_api_token` | DNS & Certs | `CLOUDFLARE_API_TOKEN` |
| `cloudflare_zone_id` | DNS Zone | `CLOUDFLARE_ZONE_ID` |

> **注意**: 所有密钥通过 `terraform.tfvars` 或 `-var` 传入，Atlantis 容器启动时注入为环境变量。

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
