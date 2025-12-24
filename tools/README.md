## 🛠️ Operational Commands (Operations Hub)

This project supports unified infrastructure commands directly from PR comments.

| Command | Action | Output |
|:---|:---|:---|
| `infra review` | AI Code Review | Appends to commit dashboard |
| `infra dig` | Connectivity Check | Appends to commit dashboard |
| `infra help` | Show help | New comment reply |

> **Note**: Commands are case-insensitive and integrated with the `infra-flash` dashboard system.

Utility scripts for infrastructure management, CI/CD, and secret synchronization.

## 📂 Tools Layout

- **`ci/`**: Python CI logic package
- **`secrets/`**:
    - `ci_load_secrets.py`: CI variable injection
    - `sync_secrets.py`: 1Password <-> GitHub Sync
- **`checks/`**:
    - `check_integrity.py`: Variable definition validation
    - `check_images.py`: Container image scanner
    - `check-readme-coverage.sh`: Documentation coverage
    - `preflight-check.sh`: Deploy safety checks
- **`ops/`**:
    - `data-import.sh`: L3 Resource import helper
    - `migrate-state.sh`: Terraform state migration

---

## Secret Loader (secrets/)
**File**: `tools/secrets/ci_load_secrets.py`
...

## Integrity Check (checks/)
**File**: `tools/checks/check_integrity.py`
...

## Sync Secrets (secrets/)
**File**: `tools/secrets/sync_secrets.py`
...

## Pre-flight Check (checks/)
**File**: `tools/checks/preflight-check.sh`
...

## L3 Import Script (ops/)
**File**: `tools/ops/data-import.sh`
...
```bash
./tools/ops/data-import.sh <namespace> [terragrunt_command]
```
### Examples
```bash
# Digger / CI
./tools/ops/data-import.sh "data-staging" "terragrunt"
./tools/ops/data-import.sh "data-prod" "terragrunt"
```

## README Coverage Check (checks/)
**File**: `tools/checks/check-readme-coverage.sh`
...
