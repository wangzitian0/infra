# terraform-setup Action

A composite GitHub Action that sets up the Terraform environment for CI/CD workflows.

## Responsibilities

1.  **SSH Setup**: Configures SSH keys for VPS access.
2.  **tfvars Rendering**: Generates `terraform.tfvars` from GitHub Secrets.
3.  **Terraform Init**: Initializes Terraform with R2 backend configuration.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `vps_host` | ✓ | VPS host IP or DNS |
| `vps_user` | ✓ | SSH user |
| `ssh_private_key` | ✓ | SSH private key content |
| `ssh_port` | ✓ | SSH port |
| `cluster_name` | ✓ | K3s cluster name |
| `r2_bucket` | ✓ | Cloudflare R2 bucket for state |
| `r2_account_id` | ✓ | Cloudflare R2 account ID |
| `github_token` | ✓ | GitHub PAT for Atlantis |
| `atlantis_webhook_secret` | ✓ | Atlantis webhook secret |
| `cloudflare_api_token` | ✓ | Cloudflare API token |
| `cloudflare_zone_id` | ✓ | Cloudflare Zone ID |
| `github_app_id` | ✗ | GitHub App ID (optional, preferred over PAT) |
| `github_app_key` | ✗ | GitHub App Private Key PEM |

## Usage

```yaml
- uses: ./.github/actions/terraform-setup
  with:
    vps_host: ${{ secrets.VPS_HOST }}
    # ... other inputs
```

## Implementation Note

tfvars generation uses a placeholder + sed/awk approach to handle multiline secrets (like `github_app_key`). This avoids heredoc nesting issues.

See [action.yml](./action.yml) for full implementation.
