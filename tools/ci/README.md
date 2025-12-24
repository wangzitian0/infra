# CI Pipeline Module

Python-driven CI/CD pipeline for infrastructure management.

## Usage

```bash
# From repo root
python -m tools.ci <command> [options]

# Or via workflow
# PR comment: /plan, /apply, /health, /e2e, /review
```

## Commands

| Command | Description |
|:---|:---|
| `plan` | Run terraform plan on specified layers |
| `apply` | Run terraform apply on specified layers |
| `verify` | Drift scan all layers (post-merge) |
| `health` | Check service connectivity |
| `parse` | Parse PR comment for slash commands |

## Structure

```
ci/
├── __init__.py
├── __main__.py          # CLI entry point
├── config.py            # Layer definitions
├── commands/
│   ├── __init__.py
│   ├── plan.py
│   ├── apply.py
│   ├── verify.py
│   ├── health.py
│   └── parse.py
└── core/
    ├── __init__.py
    ├── terraform.py     # TF/Terragrunt wrapper
    ├── github.py        # GitHub API client
    └── dashboard.py     # PR Dashboard CRUD
```
