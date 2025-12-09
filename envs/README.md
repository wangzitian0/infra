# Multi-Environment Architecture

This infrastructure follows a **4-Layer Design**, mixing Singleton (Shared) and Isolated (Namespaced) resources.

## Layer Strategy (L1-L4)

| Layer | Name | Scope | Managed By | Description |
|-------|------|-------|------------|-------------|
| **L1** | **Bootstrap** | **Shared** (Singleton) | `infra` | K3s Cluster, Atlantis CI, DNS/Cert (`kube-system`) |
| **L2** | **Platform** | **Shared** (Singleton) | `infra` | Secrets (Vault), K8s Dashboard, Kubero, Platform DB |
| **L3** | **Data** | **Isolated** (Namespace) | `staging`/`prod` | Stateful Services (Redis, Postgres) in `data-<env>` |
| **L4** | **Insight** | **Isolated** (Namespace) | `staging`/`prod` | Observability (SigNoz), Analytics (PostHog) |

## Environment Isolation

- **L1/L2 (Shared Infrastructure)**
    - Only deployed via `atlantis apply -p infra`.
    - Protected by `enable_infra=true` toggle.
    - Resources live in system namespaces (`kube-system`, `iac`, `kubernetes-dashboard`).

- **L3/L4 (Application Environments)**
    - Deployed via `atlantis apply` (Staging) or `-p prod` (Production).
    - `enable_infra=false` prevents touching L1/L2.
    - Resources are isolated by **Namespace Suffix**:
        - Staging: `data-staging`, `monitoring-staging`
        - Prod: `data-prod`, `monitoring-prod`
        - Test: `data-test`, `monitoring-test`

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

Use these files to configure non-sensitive environment variables:
- `staging.tfvars`: `env_prefix="x-staging"`, `environment="staging"`
- `prod.tfvars`: `env_prefix=""`, `environment="prod"`

---
*Last updated: 2025-12-09*
