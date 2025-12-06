# 2.env_and_networking (Environment Foundation / Layer 2)

**Scope**:
- **Networking**: Cloudflare DNS records (Ingress domains).
- **Security**: Infisical (Secrets Management) deployment.
- **Dependencies**: Platform PostgreSQL (required by Infisical).

## Architecture (Phase 0.x / 1.x)

This layer establishes the "Environment Identity" and Security Plane.
It must run **before** any application logic to ensure secrets are available.

### 1. Secrets Management (Infisical)
We use a layered approach:
- **Bootstrap**: GitHub Secrets (for VPS/Terraform access).
- **Runtime**: Infisical (Self-hosted) for ALL application secrets.

**Components**:
- **Platform PostgreSQL**: Dedicated DB for Infisical (Namespace: `iac`). **NOT** for business data.
- **Infisical Backend**: Manages encryption keys.
- **Infisical Agent**: (Future) Syncs secrets to K8s Secrets.



### 3. Usage
```bash
terraform apply -target="module.env_and_networking"
```

### 4. Disaster Recovery
- **Lost Infisical Data**: Re-apply helm chart. MongoDB/PG data persists in PVC.
- **Lost Admin Access**: Use Terraform to rotate `random_password` in state.
