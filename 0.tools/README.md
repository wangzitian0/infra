## 🛠️ Operational Commands (Operations Hub)

This project supports unified infrastructure commands directly from PR comments.

| Command | Action | Output |
|:---|:---|:---|
| `infra review` | AI Code Review | Appends to commit dashboard |
| `infra dig` | Connectivity Check | Appends to commit dashboard |
| `infra help` | Show help | New comment reply |

> **Note**: Commands are case-insensitive and integrated with the `infra-flash` dashboard system.

Utility scripts for infrastructure management, CI/CD, and secret synchronization.

## Secret Loader

**File**: `ci_load_secrets.py`

The central engine for CI variable injection. It parses the GitHub `secrets` context and maps them to Terraform variables.

### Features
- **Clean Values**: Automatically strips surrounding quotes and whitespace from 1Password exports.
- **PEM Handling**: Correctly handles multiline RSA private keys for SSH and GitHub Apps.
- **Derived Logic**: Automatically推导 derived variables（如 `TF_VAR_vault_address`）。
- **Feature Flags**: Loads boolean toggles (e.g., `ENABLE_CASDOOR_OIDC`, `ENABLE_PORTAL_SSO_GATE`) into `TF_VAR_*` for CI applies.
- **User Assignment**: Maps `GH_ACCOUNT` (GitHub email) to `TF_VAR_gh_account` for automatic Vault admin role assignment.

---

## Integrity Check

**File**: `check_integrity.py`

A shift-left guard that ensures all variables defined in `.tf` files are correctly mapped in the Python Loader. This runs automatically in CI.

---

## Sync Secrets (Standardized)

**File**: `sync_secrets.py`

The authoritative tool for syncing 1Password secrets to GitHub. It uses a predefined **Contract** to ensure consistency. It also performs local RSA key validation to prevent corrupted secrets from reaching CI.

---

## Pre-flight Check

**File**: `preflight-check.sh`

Run before `terraform apply` to catch common issues early (e.g., Helm URL validation).

---

## L3 Import Script

**File**: `l3-import.sh`

Shared script for importing existing L3 resources (namespace, Helm releases, secrets) into Terraform state. Eliminates code duplication between Atlantis CI and GitHub Actions deploy workflows.

### Usage
```bash
./0.tools/l3-import.sh <namespace> [terragrunt_command]
```

### Examples
```bash
# Atlantis (atlantis.yaml)
./0.tools/l3-import.sh "data-staging" "TG_TF_PATH=/atlantis-data/bin/terraform1.11.0 terragrunt"
./0.tools/l3-import.sh "data-prod" "TG_TF_PATH=/atlantis-data/bin/terraform1.11.0 terragrunt"
```

### Resources Imported
- `kubernetes_namespace.data`
- `helm_release.{postgresql,redis,clickhouse,arangodb_operator}`
- `kubernetes_secret.arangodb_jwt`

---

## README Coverage Check

**File**: `check-readme-coverage.sh`

CI guard that ensures READMEs are updated when code in a directory changes. Outputs:
- ✅ READMEs updated (directories that have README changes)
- ❌ READMEs need update (directories missing README changes)

Threshold: 60% of changed directories must have corresponding README updates.

---
*Last updated: 2025-12-23 (Added L3 Import Script and GH_ACCOUNT support)*
