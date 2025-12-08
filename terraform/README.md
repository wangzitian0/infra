# Terraform Root (L0)

Root configuration and orchestration module.

## Layer Structure (L1-L4)

| Layer | Directory | Purpose |
|-------|-----------|---------|
| L1 | `1.nodep/` | K3s Bootstrap + Atlantis CI + DNS/Cert (零依赖) |
| L2 | `2.platform/` | Secrets (Infisical) + K8s Dashboard + Kubero (kubectl) + Platform DB |
| L3 | `3.data/` | Business DBs (Postgres, Redis, Neo4j, ClickHouse) |
| L4 | `4.insight/` | Observability (SigNoz) + Analytics (PostHog) + Alerting |

## Key Files

| File | Purpose |
|------|---------|
| `main.tf` | Module orchestration |
| `variables.tf` | Root variables (L1 bootstrap + L2+ config) |
| `locals.tf` | Domain mappings per `network.md` convention |
| `atlantis.yaml` | (repo root) Atlantis workflow config |

## Variable Categories

### L1 Bootstrap (Required for CI/Atlantis)
| Variable | Purpose |
|----------|---------|
| `aws_access_key_id` | R2 state backend |
| `aws_secret_access_key` | R2 state backend |
| `r2_bucket` | State bucket name |
| `r2_account_id` | R2 endpoint |
| `vps_host`, `ssh_private_key` | VPS access |
| `cloudflare_api_token`, `cloudflare_zone_id` | DNS |
| `github_app_id`, `github_app_key` | Atlantis auth |

### L2+ Runtime (Managed by Infisical later)
| Variable | Purpose |
|----------|---------|
| `infisical_postgres_password` | Infisical DB |
| `env_prefix`, `base_domain` | Environment config |

## Authentication

Atlantis supports two auth modes:
- **GitHub App** (preferred): `github_app_id` + `github_app_key`
- **PAT** (fallback): `github_token`

---
*Last updated: 2025-12-08*
