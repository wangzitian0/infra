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

### Required Resources

Kubero deployment requires a `kubero-secrets` Secret (not created by Helm chart):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: kubero-secrets
  namespace: kubero-{env}
data:
  KUBERO_WEBHOOK_SECRET: <base64>  # Required for Git webhooks
  KUBERO_SESSION_KEY: <base64>      # Optional, for session management
```

This is created by Terraform in `1.kubero.tf`.

### Multi-Environment Deployment

**Known Issue**: Kubero Helm chart creates cluster-scoped `kuberorole` ClusterRole. When deploying to multiple environments (prod/staging), the second deployment fails due to Helm ownership conflict.

**Current Workaround**: 
1. First environment (staging) creates `kuberorole`
2. For second environment (prod), manually annotate the ClusterRole:
   ```bash
   kubectl annotate clusterrole kuberorole \
     meta.helm.sh/release-namespace=kubero-prod --overwrite
   kubectl label clusterrole kuberorole \
     app.kubernetes.io/managed-by=Helm --overwrite
   ```

**Long-term Fix**: Open issue with Kubero upstream to support customizable ClusterRole naming.

## SSOT Links

- [core.env.md](../docs/ssot/core.env.md) - Environment ↔ workspace/namespace/domain model
- [platform.network.md](../docs/ssot/platform.network.md) - Domain rules and routing
- [ops.pipeline.md](../docs/ssot/ops.pipeline.md) - PR → Plan/Apply workflow (Atlantis + infra-flash)

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
*Last updated: 2025-12-18*

