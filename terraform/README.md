# Terraform Root (L0)

Root configuration and orchestration module.

## Layer Structure

| Layer | Directory | Purpose |
|-------|-----------|---------|
| L1 | `1.nodep/` | K3s Bootstrap + Atlantis CI + Cloudflare DNS |
| L2 | `2.env_and_networking/` | PostgreSQL, Infisical |
| L3+ | (Planned) | Data, Insight layers |

## Key Files

| File | Purpose |
|------|---------|
| `main.tf` | Module orchestration |
| `variables.tf` | Root variables: `env_prefix`, Cloudflare, **GitHub App** |
| `locals.tf` | Domain mappings per `network.md` convention |
| `atlantis.yaml` | (repo root) Atlantis workflow config |

## Authentication

Atlantis supports two auth modes (configured in `variables.tf`):
- **GitHub App** (preferred): `github_app_id` + `github_app_key`
- **PAT** (fallback): `github_token`
