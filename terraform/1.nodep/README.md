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
| `2.atlantis.tf` | Atlantis Helm release for Terraform CI/CD (2Gi RAM) |
| `3.dns_and_cert.tf` | Cloudflare DNS (wildcard + x-*), Cert Manager, wildcard TLS cert |
| `4.storage.tf` | Harden local-path: /data storage path + Retain StorageClass |
| `network.md` | Domain naming conventions (SSOT) |

## DNS Architecture

See [network.md](network.md) for full domain design.

| Pattern | Cloudflare | Purpose | Example |
|---------|------------|---------|---------|
| `i-*` | Grey cloud (DNS-only) | Internal/infra services | `i-atlantis`, `i-secrets` |
| `x-*` | Orange cloud (proxied) | Test environments | `x-staging-api`, `x-testpr-123-app` |
| `@` | Orange cloud (proxied) | Production | `truealpha.club`, `api.truealpha.club` |

**DNS Records managed here**:
- `*` (wildcard) → VPS IP (grey cloud)
- `@` (root) → VPS IP (orange cloud)
- `x-staging` → VPS IP (orange cloud)

**Note**: Production uses direct domain (`api.base.com`), no `x-prod` prefix.

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
| `github_app_id` | GitHub App ID (optional) | (Helm githubApp.id) |
| `github_app_key` | GitHub App Private Key | (Helm githubApp.key) |
| `cloudflare_api_token` | DNS & Certs | `CLOUDFLARE_API_TOKEN` |
| `cloudflare_zone_id` | DNS Zone | `CLOUDFLARE_ZONE_ID` |

> **注意**: 所有密钥通过 `terraform.tfvars` 或 `-var` 传入，Atlantis 容器启动时通过 Helm `environment` 块注入为环境变量。Terraform 变量使用 `TF_VAR_` 前缀（如 `TF_VAR_vps_host`）。

### 2. Variable Chain (CI → Atlantis)

```
GitHub Secrets
     ↓
terraform-setup action (inputs)
     ↓
terraform.tfvars (generated)
     ↓
terraform/variables.tf (root)
     ↓
main.tf → module.nodep (pass-through)
     ↓
2.atlantis.tf: environment block → Atlantis pod env vars
```

### 3. Execution
```bash
terraform init -backend-config=...
terraform apply -target="module.nodep" -var-file="envs/staging.tfvars"
```

**Effect**:
- Installs k3s single-node cluster.
- Deploys Atlantis for Terraform CI/CD.
- Generates `kubeconfig` (output).
- Prepares node for subsequent layers.

## Post-Apply Validation

After `terraform apply`, these checks run automatically:
1. **DNS**: Verifies wildcard DNS resolves correctly.
2. **Cert**: Waits for TLS certificate to be issued (max 2 min).
3. **Atlantis**: Checks `/healthz` endpoint is reachable.

## Storage Notes
- Local-path provisioner is patched to use `/data/local-path-provisioner` as the sole storage path.
- New StorageClass `local-path-retain` has `ReclaimPolicy=Retain` to prevent accidental data deletion; cleanup of released PVs is manual.
- **Important**: `/data` directory must exist on VPS before apply (created manually or via cloud-init).

---
*Last updated: 2025-12-09*
