# 4.apps (L4 Applications Layer)

**Scope**: Application control plane + workload deployments.

## Architecture

### Singleton Control Plane

L4 deploys a **single** control plane (Kubero + SigNoz) that manages multi-environment workloads via Pipeline/Phase:

| Component | Namespace | Mode | Purpose |
|-----------|-----------|------|---------|
| Kubero Operator | `kubero-operator-system` | Singleton | GitOps PaaS Controller |
| Kubero UI | `kubero` | Singleton | GitOps PaaS UI (`kcloud.zitian.party`) |
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

### Multi-Environment Deployment

**Old Design (deprecated)**:
- ~~Two TF workspaces (staging/prod) each creating their own kubero namespace~~

**New Design (current)**:
- Single TF workspace (default) deploys singleton control plane
- Kubero Pipeline/Phase manages app deployments to `apps-staging` / `apps-prod`

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

## TODO: 开发者体验改进

### 1. 缺少 Kubero 使用指南
**问题**: 当前 README 主要是架构说明和 Troubleshooting，但缺少开发者最需要的"如何使用 Kubero 部署我的应用"。

**建议**:
- [ ] 新增 "## Developer Guide: 在 Kubero 上部署应用" 章节
- [ ] 包含以下内容：
  - 如何访问 Kubero UI (`https://kcloud.<internal_domain>`)
  - 如何创建第一个 Pipeline
  - 如何配置 Phase (staging/prod)
  - 如何连接 Git 仓库
  - 如何配置环境变量（从 Vault 注入密钥）
  - 如何触发部署
  - 如何查看日志和状态
- [ ] 提供一个完整的示例应用（如 Node.js Hello World）的部署步骤

**受影响角色**: 应用开发者（首次使用 Kubero）

### 2. 环境划分说明不清晰
**问题**: 文档提到 `apps-staging` 和 `apps-prod` namespace，但没有明确说明开发者应该如何选择环境。

**建议**:
- [ ] 在 "Multi-Environment via Kubero Pipeline" 章节增加开发者视角的说明
- [ ] 明确说明：
  - Staging 环境用于什么？（测试、预发布）
  - Prod 环境用于什么？（生产流量）
  - 如何在两个环境间推进代码？
  - 环境间的资源隔离策略（数据库、密钥等）

**受影响角色**: 应用开发者（环境管理）

### 3. SigNoz 和 PostHog 使用文档缺失
**问题**: README 提到了 SigNoz（监控）和 PostHog（分析），但完全没有使用说明。

**建议**:
- [ ] 新增 "## Observability: SigNoz 和 PostHog" 章节
- [ ] SigNoz 部分：
  - 访问地址
  - 如何在应用中接入 OpenTelemetry
  - 常见的监控指标和追踪示例
- [ ] PostHog 部分：
  - 访问地址
  - 如何在前端/后端接入 PostHog SDK
  - 常见的分析场景（事件追踪、用户行为分析）

**受影响角色**: 应用开发者（可观测性需求）
