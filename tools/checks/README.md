# Integrity & Pre-flight Checks

> **Role**: Validation & Compliance Scripts

This directory contains scripts used to ensure infrastructure integrity and validate changes before deployment.

## 📚 SSOT References

- [**Ops Standards SSOT**](../../docs/ssot/ops.standards.md)

## Tools

| Script | Purpose |
|--------|---------|
| `check_integrity.py` | Validates that all `TF_VAR_` are defined in Terraform. |
| `preflight-check.sh` | Runs local pre-checks (lint, fmt) before commit. |
| `check_images.py` | Scans for container image security/validity. |
| `check-readme-coverage.sh` | Ensures every critical directory has a README. |

## Usage

```bash
# Run integrity check
python3 tools/checks/check_integrity.py
```
