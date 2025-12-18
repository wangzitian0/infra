# Scripts

Utility scripts for infrastructure management, CI/CD, and secret synchronization.

## Secret Loader

**File**: `ci_load_secrets.py`

The central engine for CI variable injection. It parses the GitHub `secrets` context and maps them to Terraform variables.

### Features
- **Clean Values**: Automatically strips surrounding quotes and whitespace from 1Password exports.
- **PEM Handling**: Correctly handles multiline RSA private keys for SSH and GitHub Apps.
- **Derived Logic**: Automatically推导 derived variables（如 `TF_VAR_vault_address`）。

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
