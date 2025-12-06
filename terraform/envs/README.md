# Multi-Environment Architecture

This infrastructure follows a **5-Layer Design**, mixing Singleton (Shared) and Isolated (Namespaced) resources.

## Layer Strategy

| Layer | Name | Scope | Managed By | Description |
|-------|------|-------|------------|-------------|
| **L1** | **Bootstrap** | **Shared** (Singleton) | `infra` | K3s Cluster, Nodes, SSH, System Config (`kube-system`) |
| **L2** | **Networking** | **Shared** (Singleton) | `infra` | Ingress Controller, Cert-Manager, Ext-Secrets, Base DNS |
| **L3** | **Platform** | **Isolated** (Namespace) | `staging`/`prod` | Environment-specific tools (e.g. `monitoring-staging`) |
| **L4** | **Data** | **Isolated** (Namespace) | `staging`/`prod` | Stateful Services (Redis, Postgres) in `data-<env>` |
| **L5** | **Insight** | **Isolated** (Namespace) | `staging`/`prod` | Business Applications in `app-<env>` |

## Environment Isolation

- **L1/L2 (Shared Infrastructure)**
    - Only deployed via `atlantis apply -p infra`.
    - Protected by `enable_infra=true` toggle.
    - Resources live in system namespaces (`ingress-nginx`, `cert-manager`).

- **L3+ (Application Environments)**
    - Deployed via `atlantis apply` (Staging) or `-p prod` (Production).
    - `enable_infra=false` prevents touching L1/L2.
    - Resources are isolated by **Namespace Suffix**:
        - Staging: `app-staging`, `data-staging`
        - Prod: `app-prod`, `data-prod`
        - Test: `app-test`, `data-test`

## tfvars usage

Use these files to configure non-sensitive environment variables:
- `staging.tfvars`: `env_prefix="x-staging"`, `environment="staging"`
- `prod.tfvars`: `env_prefix=""`, `environment="prod"`
