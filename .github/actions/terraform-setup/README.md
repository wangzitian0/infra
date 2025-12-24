# terraform-setup Action

A composite GitHub Action that sets up the Terraform environment for CI/CD workflows using a unified secret loader.

## Responsibilities

1. **Secret Loading**: Uses `tools/ci_load_secrets.py` to parse GitHub Secrets and map them to `TF_VAR_` variables.
2. **SSH Setup**: Configures SSH keys for VPS access (inherited from loader).
3. **Terraform Init**: Initializes Terraform with R2 backend configuration.
4. **Kubeconfig Fetch**: Retrieves kubeconfig from VPS for Helm provider.
5. **Robustness**: Provides default values for optional settings and safe variable handling to prevent CI crashes.

## Inputs

| Input | Required | Description |
|-------|----------|-------------|
| `secrets_json` | ✓ | All GitHub Secrets in JSON format (pass `${{ toJSON(secrets) }}`) |
| `terraform_version` | ✗ | Terraform version (default: reads from `.terraform-version` file) |
| `tf_state_key` | ✗ | State file key in bucket (default: terraform.tfstate) |
| `working_directory` | ✗ | Directory for Terraform operations (default: 1.bootstrap) |

## Usage

```yaml
- uses: ./.github/actions/terraform-setup
  with:
    secrets_json: ${{ toJSON(secrets) }}
    tf_state_key: "k3s/platform.tfstate"
    working_directory: "2.platform"
```

## Variable Chain (Modern Flow)

```
1Password (SSOT) → GitHub Secrets (Cache) → ci_load_secrets.py → TF_VAR_*
```

See [action.yml](./action.yml) for full implementation.

---
*Last updated: 2025-12-22*