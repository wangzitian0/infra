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

### Components (Planned)

| Component | Purpose |
|-----------|---------|
| Kubero | GitOps PaaS UI (L4 Controller) |
| Frontend | User-facing web app |
| Backend API | Business logic |
| Workers | Background jobs |

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
*Last updated: 2025-12-16*

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
