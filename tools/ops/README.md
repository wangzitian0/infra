# Operational Scripts (Ops)

> **Role**: Ad-hoc Infrastructure Management

This directory contains scripts for manual or scheduled operational tasks.

## 📚 SSOT References

- [**Recovery SSOT**](../../docs/ssot/ops.recovery.md)
- [**Storage SSOT**](../../docs/ssot/ops.storage.md)

## Tools

| Script | Purpose | SSOT Playbook |
|--------|---------|---------------|
| `data-import.sh` | Helper for importing resources to TF state. | N/A |
| `migrate-state.sh` | Terraform state migration helper. | N/A |
| `fix_bootstrap_drift.sh` | Fixes common drift issues in L1. | [Recovery](./docs/ssot/ops.recovery.md) |

## Usage

```bash
# Example: Import data-staging resources
./tools/ops/data-import.sh data-staging
```
