# terraform-setup Action

A composite GitHub Action that sets up the Terraform environment for CI/CD workflows.

## Responsibilities

1. **SSH Setup**: Configures SSH keys for VPS access.
2. **tfvars Rendering**: Generates `terraform.tfvars` from GitHub Secrets.
3. **Terraform Init**: Initializes Terraform with R2 backend configuration.
4. **Kubeconfig Fetch**: Retrieves kubeconfig from VPS for Helm provider.
5. **Terraform Wrapper**: Runs `hashicorp/setup-terraform@v3` with `terraform_wrapper: false` so wrapper instrumentation does not intercept `terraform` exit codes and scripts can safely catch failed `state show`/`state rm` checks.

## Inputs

### L1 Bootstrap: R2 Backend
| Input | Required | Description |
|-------|----------|-------------|
| `aws_access_key_id` | ✓ | AWS Access Key ID for R2 |
| `aws_secret_access_key` | ✓ | AWS Secret Access Key for R2 |
| `r2_bucket` | ✓ | Cloudflare R2 bucket for state |
| `r2_account_id` | ✓ | Cloudflare R2 account ID |
| `tf_state_key` | ✗ | State file key in bucket (default: terraform.tfstate) |

### L1 Bootstrap: VPS/SSH
| Input | Required | Description |
|-------|----------|-------------|
| `vps_host` | ✓ | VPS host IP or DNS |
| `vps_user` | ✗ | SSH user (default: root) |
| `vps_ssh_key` | ✓ | SSH private key content |
| `vps_ssh_port` | ✗ | SSH port (default: 22) |

### L1 Bootstrap: Cloudflare
| Input | Required | Description |
|-------|----------|-------------|
| `cloudflare_api_token` | ✓ | Cloudflare API token |
| `cloudflare_zone_id` | ✓ | Cloudflare Zone ID |
| `base_domain` | ✓ | Base domain for services |

### L1 Bootstrap: Atlantis/GitHub
| Input | Required | Description |
|-------|----------|-------------|
| `github_token` | ✓ | GitHub PAT for Atlantis |
| `atlantis_webhook_secret` | ✓ | Atlantis webhook secret |
| `github_app_id` | ✗ | GitHub App ID (preferred over PAT) |
| `github_app_key` | ✗ | GitHub App Private Key PEM |

### L2 Platform
| Input | Required | Description |
|-------|----------|-------------|
| `vault_postgres_password` | ✓ | Vault storage backend PostgreSQL password |

## Usage

```yaml
- uses: ./.github/actions/terraform-setup
  with:
    aws_access_key_id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws_secret_access_key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    r2_bucket: ${{ secrets.R2_BUCKET }}
    r2_account_id: ${{ secrets.R2_ACCOUNT_ID }}
    vps_host: ${{ secrets.VPS_HOST }}
    vps_ssh_key: ${{ secrets.VPS_SSH_KEY }}
    # ... other inputs
```

## Variable Chain

```
GitHub Secrets → action inputs → env vars → tfvars file → Terraform variables
```

See [action.yml](./action.yml) for full implementation.

---
*Last updated: 2025-12-09*
