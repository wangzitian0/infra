# Terraform Root (L0)

Root configuration and orchestration module.

## Layer Structure

| Layer | Directory | Purpose |
|-------|-----------|---------|
| L1 | `1.nodep/` | K3s Bootstrap + Atlantis CI |
| L2 | `2.env_and_networking/` | PostgreSQL, Infisical |
| L3+ | (Planned) | Data, Insight layers |

## Key Files

| File | Purpose |
|------|---------|
| `main.tf` | Module orchestration |
| `variables.tf` | Root variables incl. Atlantis secrets |
| `atlantis.yaml` | (repo root) Atlantis workflow config |
