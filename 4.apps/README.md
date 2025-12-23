# 4.apps (L4 Applications Layer)

> **定位**：模块维护文档（面向基础设施运维者）
> **开发者？** → 请先看 [开发者接入指南](../docs/onboarding/README.md)
> **部署验证？** → 见 [E2E 回归测试](../docs/ssot/ops.e2e-regressions.md)

**Scope**: Application control plane + workload deployments.

## Architecture

### Singleton Control Plane

L4 deploys a **single** control plane (Kubero + SigNoz) that manages multi-environment workloads via Pipeline/Phase:

| Component | Namespace | Mode | Purpose |
|-----------|-----------|------|---------|
| Kubero Operator | `kubero-operator-system` | Singleton | GitOps PaaS Controller |
| Kubero UI | `kubero` | Singleton | GitOps PaaS UI (`kcloud.zitian.party`) |
| **SigNoz** | `observability` | Singleton | Metrics/Traces/Logs (`signoz.zitian.party`) |
| Workloads | `apps-staging` / `apps-prod` | Per-env | Managed by Kubero Pipeline/Phase |

### Multi-Environment via Kubero Pipeline

```
Kubero (1 套控制面)
├── Pipeline: app-a
│   ├── phase: staging → namespace: apps-staging
│   └── phase: prod    → namespace: apps-prod
└── Pipeline: app-b
    └── ...
```

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

### Deployment & Configuration

**Architecture**: Singleton control plane (managed via Terragrunt)
- Single deployment controls all environments
- Kubero Pipeline/Phase manages app deployments to `apps-staging` / `apps-prod`
- No Terraform workspace needed

**Terragrunt Integration**:
- **Backend/Providers**: Auto-generated (gitignored)
- **State key**: `k3s/apps.tfstate` (singleton)

```bash
# Standalone usage
cd 4.apps
export R2_BUCKET=<bucket> R2_ACCOUNT_ID=<account-id>
terragrunt init
terragrunt apply
```

## 相关文档

**开发者指南**（场景驱动）：
- [部署第一个应用](../docs/onboarding/02.first-app.md) - Kubero 使用教程
- [使用数据库](../docs/onboarding/03.database.md) - 数据库接入
- [监控和分析](../docs/onboarding/06.observability.md) - SigNoz + PostHog

**SSOT 参考**（技术细节）：
- [core.env.md](../docs/ssot/core.env.md) - 环境模型
- [platform.network.md](../docs/ssot/platform.network.md) - 域名规则
- [ops.pipeline.md](../docs/ssot/ops.pipeline.md) - CI/CD 流程
- [platform.auth.md](../docs/ssot/platform.auth.md) - 认证策略

## Troubleshooting

### Atlantis Lock Failure
If Atlantis fails to delete PR locks, it might be due to a workspace lock. Use `atlantis unlock` command in the PR.

### Usage

```bash
# Plan and Apply (singleton)
atlantis plan -p apps
atlantis apply -p apps
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

---

