# terraform-setup Action

A composite GitHub Action that sets up the Terraform environment for CI/CD workflows.

## Responsibilities

1.  **SSH Setup**: Configures SSH keys for VPS access.
2.  **tfvars Rendering**: Generates `terraform.tfvars` from GitHub Secrets.
3.  **Terraform Init**: Initializes Terraform with R2 backend configuration.

## Inputs

- `terraform_version` (default: 1.6.6)
- `aws_access_key_id` (R2)
- `aws_secret_access_key` (R2)
- `r2_bucket`
- `r2_account_id`
- `vps_host`
- `vps_user` (default: root)
- `vps_ssh_key`
- `vps_ssh_port` (default: 22)
- `k3s_cluster_name` (optional, for kubeconfig fetch)

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
