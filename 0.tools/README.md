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
./preflight-check.sh
```

### Integration

This script is automatically run by:
- `terraform-plan.yml` (PR CI)
- `deploy-k3s.yml` (Deploy CI)

## Check Images

**File**: `check_images.py`

Purpose: Pre-verify existence of Docker Hub image tags to avoid `ImagePullBackOff` during deployment.

### Usage

```bash
python3 0.tools/check_images.py nginx:1.27 postgres:16
```

> Requires internet access to `auth.docker.io` and `registry-1.docker.io`.