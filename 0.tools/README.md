# Scripts

Utility scripts for infrastructure management, CI/CD, and secret synchronization.

## Secret Loader

**File**: `ci_load_secrets.py`

The central engine for CI variable injection. It parses the GitHub `secrets` context and maps them to Terraform variables.

### Features
- **Clean Values**: Automatically strips surrounding quotes and whitespace from 1Password exports.
- **PEM Handling**: Correctly handles multiline RSA private keys for SSH and GitHub Apps.
- **Defaults**: Provides fallback values for optional infrastructure settings (e.g., SSH port, cluster name).

---

## Pre-flight Check

**File**: `preflight-check.sh`

Run before `terraform apply` to catch common issues early.

### Checks Performed
- **Helm URL Validation**: Verifies all Helm repository URLs in `.tf` files are reachable.

---

## Check Images

**File**: `check_images.py`

Purpose: Pre-verify existence of Docker Hub image tags to avoid `ImagePullBackOff` during deployment.

---

## Sync Secrets (Local)

To sync secrets from 1Password to GitHub, use the pattern described in [docs/ssot/platform.secrets.md](../docs/ssot/platform.secrets.md).