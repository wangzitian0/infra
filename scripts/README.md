# Scripts

Utility scripts for infrastructure management and CI/CD.

## Pre-flight Check

**File**: `preflight-check.sh`

Run before `terraform apply` to catch common issues early.

### Checks Performed

| Check | Description |
|-------|-------------|
| Helm URL Validation | Verifies all Helm repository URLs in `.tf` files are reachable |

### Usage

```bash
./scripts/preflight-check.sh
```

### Integration

This script is automatically run by:
- `terraform-plan.yml` (PR CI)
- `deploy-k3s.yml` (Deploy CI)
