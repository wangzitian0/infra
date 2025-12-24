# Tools

> **Role**: Operational Utilities & Scripts
> **Dependencies**: Python 3.11+, Bash

This directory contains utility scripts for CI/CD, secret management, and operational tasks.

## 📂 Directory Structure

| Directory | Purpose | Key Tools |
|-----------|---------|-----------|
| `ci/` | **CI Logic** | Dashboard management, Command parsing |
| `secrets/` | **Secrets** | `ci_load_secrets.py`, `sync_secrets.py` |
| `checks/` | **Validation** | `check_integrity.py`, `preflight-check.sh` |
| `ops/` | **Operations** | `data-import.sh`, `migrate-state.sh` |
| `envs/` | **Contracts** | `env.ci` (Variable contract) |

## 📚 SSOT References

- **Pipeline Logic**: [**Pipeline SSOT**](../docs/ssot/ops.pipeline.md)
- **Secret Management**: [**Secrets SSOT**](../docs/ssot/platform.secrets.md)
- **Environment Contract**: [**Core SSOT / Variables**](../docs/ssot/core.md)

## 🛠️ Key Scripts

### CI Loader
> Used by GitHub Actions to inject secrets.
- Path: `tools/secrets/ci_load_secrets.py`
- SSOT: [Platform Secrets SSOT](../docs/ssot/platform.secrets.md)

### Integrity Check
> Validates that all `TF_VAR_` used in code are defined in variables.tf.
- Path: `tools/checks/check_integrity.py`
- Usage: `python3 tools/checks/check_integrity.py`

### Data Import
> Helper for importing existing resources into Terraform state.
- Path: `tools/ops/data-import.sh`

---
*Last updated: 2025-12-25*