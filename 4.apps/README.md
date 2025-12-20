# 4.apps (L4 Applications Layer)

**Scope**: Application deployments for prod/staging environments.

- **Environments**: `prod`, `staging` only
- **Namespace**: `apps-prod`, `apps-staging`

## Architecture

This layer deploys business applications. All non-production environments go to `staging`.

### Deployment Strategy

| Environment | Namespace | Purpose |
|-------------|-----------|---------|
| `staging` | `apps-staging` | All test/dev/preview environments |
| `prod` | `apps-prod` | Production only |

### Components

| Component | Status | Purpose |
|-----------|--------|---------|
| Kubero Operator | ✅ Deployed | GitOps PaaS Controller (in `kubero-operator-system-{env}`) |
| Kubero UI | ✅ Deployed | GitOps PaaS UI (in `kubero-{env}`, accessible at `kcloud.zitian.party`) |

## Kubero Configuration

### Helm Values Mapping

The Kubero CR uses specific value paths (differs from typical Helm conventions):

| Feature | Correct Path | Notes |
|---------|--------------|-------|
| PVC StorageClass | `kubero.database.storageClassName` | NOT `persistence.storageClass` |
| Session Key | `kubero.sessionKey` | Used for session encryption |
| Namespace | `kubero.namespace` | Target namespace for Kubero UI |

### Required Secrets

Kubero secrets (Webhook and Session keys) are centralized in **Vault KV** (`secret/data/kubero`) and injected into the pods via the **Vault Agent Injector**.

The following annotations are required (and managed by Terraform in `1.kubero.tf`):
```yaml
vault.hashicorp.com/agent-inject: "true"
vault.hashicorp.com/role: "kubero"
vault.hashicorp.com/agent-inject-secret-env: "secret/data/kubero"
```

### OIDC (Casdoor)

Kubero uses **native Casdoor OIDC** (no Portal Gate / ForwardAuth) to avoid double authentication.
When `enable_casdoor_oidc=true` (or legacy `enable_portal_sso_gate=true`), Kubero enables Casdoor OIDC login using the `kubero-oidc` client.
Vault must contain the following keys in `secret/data/kubero` (written by L2):

- `KUBERO_OIDC_CLIENT_ID`
- `KUBERO_OIDC_CLIENT_SECRET`

Callback: `https://kcloud.<internal_domain>/auth/callback`

### Multi-Environment Deployment

**Issue**: Kubero Helm chart originally created a hardcoded `kuberorole` ClusterRole, causing conflicts between environments.

**Resolution**: The `1.kubero.tf` file now programmatically replaces naming in the manifests with environment suffixes (e.g., `kuberorole-prod`, `kuberorole-staging`). No manual intervention is required.

## SSOT Links

- [core.env.md](../docs/ssot/core.env.md) - Environment ↔ workspace/namespace/domain model
- [platform.network.md](../docs/ssot/platform.network.md) - Domain rules and routing
- [ops.pipeline.md](../docs/ssot/ops.pipeline.md) - PR → Plan/Apply workflow (Atlantis + infra-flash)
- [platform.auth.md](../docs/ssot/platform.auth.md) - Authentication strategy (Casdoor + Vault)

## Troubleshooting

### Atlantis Lock Failure
If Atlantis fails to delete PR locks, it might be due to a workspace lock. Use `atlantis unlock` command in the PR.

### Usage

```bash
# Staging
atlantis plan -p apps-staging
atlantis apply -p apps-staging

# Production
atlantis plan -p apps-prod
atlantis apply -p apps-prod
```

---

- **README 维护提醒**：新增了 `scripts/check-readme-coverage.sh` 与 `.github/workflows/readme-coverage.yml`，要求修改目录要同步更新对应 `README.md`，覆盖率必须达到 80%。

## Troubleshooting

### Stuck Namespace: `kubero`

If `atlantis apply` fails with `namespaces "kubero" already exists` or `namespaces "kubero-operator-system" already exists`, it means legacy L2 resources were not fully cleaned up.

If `kubectl delete ns kubero` hangs, it is likely due to the orphan `kubero` Custom Resource (CR) holding a finalizer:

```bash
# 1. Check for stuck resource
kubectl get kuberoes.application.kubero.dev -n kubero

# 2. Patch finalizer to release it
kubectl patch kuberoes.application.kubero.dev kubero -n kubero \
  -p '{"metadata":{"finalizers":[]}}' --type=merge

# 3. Namespace should terminate
kubectl get ns kubero
```

### Secret Not Found: `kubero-secrets`

If Kubero pods fail with `CreateContainerConfigError: secret "kubero-secrets" not found`:

```bash
# Check if Terraform created the secret
kubectl get secret kubero-secrets -n kubero-prod

# If missing, re-run Terraform apply
atlantis apply -p apps-prod
```

### PVC Pending: No StorageClass

If PVC is stuck in Pending with "no storage class set":
- Verify `kubero.database.storageClassName` is set in CR (not `persistence.storageClass`)
- Delete PVC and let operator recreate: `kubectl delete pvc kubero-data -n kubero-prod`

---
### Secret Not Found: `kubero-secrets`

If Kubero pods fail with `CreateContainerConfigError: secret "kubero-secrets" not found`:
- Verify `kubernetes_secret.kubero_secrets` exists in Namespace.
- The secret is now synced from **Vault** via Terraform for operator compatibility.

*Last updated: 2025-12-20*
