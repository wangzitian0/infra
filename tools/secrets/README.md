# Secrets Tools

> **Role**: Secret Management Utilities
> **Dependencies**: 1Password CLI (`op`), GitHub CLI (`gh`)

This directory contains scripts for synchronizing and loading infrastructure secrets.

## 📚 SSOT References

> [**Platform Secrets SSOT**](../../docs/ssot/platform.secrets.md)

## Components

| File | Purpose | SSOT Context |
|------|---------|--------------|
| `ci_load_secrets.py` | **Python Loader** | Maps GitHub Secrets to `TF_VAR_*` in CI pipelines |
| `sync_secrets.py` | **Sync Utility** | Syncs 1Password items to GitHub Secrets + local tfvars |

## Usage

### CI Loader
Used in GitHub Actions workflows:
```yaml
- name: Load Secrets
  run: python3 tools/secrets/ci_load_secrets.py
```

### Sync Script (Local)
Used by Ops to update GitHub Secrets:
```bash
# Requires 'op' and 'gh' CLI authenticated
python3 tools/secrets/sync_secrets.py
```

When prompted, enter a 3-digit selector for targets in this order:
```
GitHub Secrets / tfvars.example / tfvars
```

Example: write only `bootstrap/local.tfvars.example`:
```bash
# 010
python3 tools/secrets/sync_secrets.py
```

---
*Last updated: 2025-12-25*
