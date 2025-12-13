# Multi-Environment Architecture

This directory documents **how we represent environments** via `*.tfvars` files.

> Architecture SSOT lives in `docs/ssot/` (especially `docs/ssot/env.md`). This README is operational guidance, not a second SSOT.

## Layer Strategy (L1-L4)

| Layer | Name | Scope | Managed By | Description |
|-------|------|-------|------------|-------------|
| **L1** | **Bootstrap** | **Shared** (Singleton) | GitHub Actions | K3s Cluster, Atlantis, DNS/Cert, Storage, Platform PG |
| **L2** | **Platform** | **Shared** (Singleton) | Atlantis (`platform`) | Vault, Dashboard, Kubero, Casdoor |
| **L3** | **Data** | **Isolated** (Per-env) | Atlantis (`data-<env>`) | Business databases in `data-<env>` |
| **L4** | **Apps** | **Isolated** (Per-env) | Atlantis (`apps-<env>`) | Business apps in `apps-<env>` |

## Environment Isolation

- **Shared layers (L1/L2)**: single instance shared by all envs (single VPS MVP).
- **Env layers (L3/L4)**: isolated by **workspace + namespace suffix**:
  - Staging: `data-staging`, `apps-staging`
  - Prod: `data-prod`, `apps-prod`

## Design Decision: Namespace vs Cluster Isolation

**Decision**: Use **Namespace Isolation** (Soft Multi-Tenancy) instead of separate Clusters.

**Rationale**:
1.  **Cost Efficiency**: Running multiple K3s clusters doubles/triples infrastructure requirements.
2.  **Operational Simplicity**: Managing one set of L1/L2 reduces maintenance burden.
3.  **Scale Appropriateness**: For this project size, separate physical clusters introduce unnecessary complexity.

**Trade-offs**:
- **Risk**: Shared Failure Domain. If the L1 Cluster fails, *both* Staging and Prod go down.
- **Mitigation**:
    - `staging` deployment verifies application logic.
    - `infra` workflow is separated to prevent accidental cluster-wide changes during app deployment.
    - Resource Quotas (CPU/RAM) can be applied to namespaces.

## tfvars usage

Use these files to configure **non-sensitive** environment variables:
- `envs/staging.tfvars` (not committed; use `staging.tfvars.example` as template)
- `envs/prod.tfvars` (not committed; create similarly)

Recommended minimum content:
- `environment = "staging"|"prod"`
- `base_domain = "..."`
- `internal_domain = "..."` (optional; defaults to base_domain)
- `env_prefix = "x-staging"|""` (business domains only)

For the authoritative environment model, see: `docs/ssot/env.md`.

---
*Last updated: 2025-12-09*
