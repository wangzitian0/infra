# 流程 SSOT

> **核心问题**：如何保证 Plan = Apply = 实际状态？

**答案**：变量一致性 + 版本锁定 + 分层检查

---

## 1. 一致性保证

### 变量流

```
1Password (SSOT)
     ↓ op item get + gh secret set
GitHub Secrets
     ├─→ CI (terraform-plan.yml)     → TF_VAR_*
     └─→ Atlantis Pod (deploy-k3s)   → TF_VAR_*
              ↓
         terraform plan/apply
              ↓
         Kubernetes 资源
```

### 变量一致性检查表

| 变量 | CI 来源 | Atlantis 来源 | 验证 |
|------|---------|---------------|------|
| `vault_postgres_password` | `secrets.VAULT_POSTGRES_PASSWORD` | Pod env | ✅ |
| `vault_root_token` | `secrets.VAULT_ROOT_TOKEN` | Pod env | ✅ |
| `vault_address` | 外部 URL | 内部 DNS | **不同但正确** |
| `cloudflare_api_token` | `secrets.CLOUDFLARE_API_TOKEN` | Pod env | ✅ |

**vault_address 差异说明**：
- CI：`https://secrets.{domain}` （外部访问）
- Atlantis：`http://vault.platform.svc:8200` （集群内）
- 两者都能正确连接 Vault

### 版本锁定

```hcl
# versions.tf - 固定 provider 版本
terraform {
  required_version = ">= 1.6.0"
  required_providers {
    kubernetes = { version = "~> 2.25" }
    helm       = { version = "~> 2.12" }
    vault      = { version = "~> 4.2" }
  }
}
```

```
# .terraform.lock.hcl 提交到 Git
# 确保 CI 和 Atlantis 用相同 provider 版本
```

---

## 2. 健康检查分层

```
┌─────────────────────────────────────────────────────────────┐
│  时机        │  能力                │  作用                 │
├─────────────────────────────────────────────────────────────┤
│  Plan       │  variable.validation │  拒绝无效输入          │
│  Apply 前   │  precondition        │  验证依赖就绪          │
│  Pod 启动   │  initContainer       │  等待依赖可用          │
│  运行时     │  readiness/liveness  │  流量控制 / 自动重启   │
│  Apply 后   │  postcondition       │  验证部署成功          │
└─────────────────────────────────────────────────────────────┘
```

### 依赖拓扑

```
PostgreSQL ─┬─→ Vault       (initContainer 等待 PG)
            ├─→ Casdoor     (initContainer 等待 PG)
            │       └─→ Portal-Auth (initContainer 等待 Casdoor)
            └─→ L3 Postgres (initContainer 等待 PG)
```

### initContainer 实现状态

| 组件 | 等待 | 状态 |
|------|------|------|
| Vault | PostgreSQL | ✅ |
| Casdoor | PostgreSQL | ✅ |
| Portal-Auth | Casdoor | ✅ |

---

## 3. 部署流程

### L1 Bootstrap（GitHub Actions）

```
push to main
     ↓
terraform fmt/lint/validate
     ↓
terraform plan (CI 预览)
     ↓
terraform apply (自动)
```

### L2-L4（Atlantis GitOps）

```
PR 创建
     ↓
CI plan (语法+安全检查)
     ↓
atlantis plan (实际 plan)
     ↓
Review
     ↓
atlantis apply
     ↓
Merge
```

**Lock 策略**：
- `parallel_plan: true` - 多 PR 并行 plan
- `parallel_apply: false` - apply 串行，避免冲突

---

## 4. Plan/Apply 常见问题

### State Stale

```
Error: Saved plan is stale
```

**原因**：Plan 后 state 被其他操作修改
**解决**：重新 `atlantis plan`

### Provider 不匹配

```
Error: Inconsistent dependency lock file
```

**原因**：`.terraform.lock.hcl` 变更
**解决**：
1. 本地 `terraform init -upgrade`
2. 提交 `.terraform.lock.hcl`

### Plugin Cache 竞争

```
Error: text file busy
```

**原因**：`parallel_plan: true` 时，若多个 Atlantis projects 指向同一目录（例如同一模块的不同 workspace），并行 `rm -rf .terraform` / `terraform init` 会互相踩踏，导致 provider 文件被占用。
**解决**：通过 `atlantis.yaml` 的 `execution_order_group` 将同目录的 projects 串行化；或只对单个 project 运行 `atlantis plan -p <project>`。

### Workspace 已存在

```
Error: Workspace "prod" already exists
```

**原因**：同目录的多 workspace 并行 plan 时，`terraform workspace new`/`select` 存在竞争条件。
**解决**：同上（用 `execution_order_group` 串行化）；必要时 `atlantis unlock` 后重跑 `atlantis plan`。

### 变量缺失

```
Error: No value for required variable
```

**检查**：
1. GitHub Secrets 是否存在
2. CI workflow 是否传递
3. Atlantis Pod env 是否有

---

## 5. 灾难恢复

| 场景 | 恢复 |
|------|------|
| Pod 挂 | K8s 自动重建 |
| 依赖未就绪 | initContainer 等待 |
| Vault sealed | `vault operator unseal <key>` |
| PG 数据丢失 | 删 PVC → apply → reinit |
| VPS 丢失 | 1Password → 新 VPS → L1 → L2 |

### 1Password 密钥

- `Vault Unseal Keys` - unseal
- `Vault Root Token` - TF provider
- `Casdoor Admin` - SSO 管理
- `VPS SSH Key` - 服务器访问
- `R2 Credentials` - TF state

---

## 相关文件

| 文件 | 用途 |
|------|------|
| `docs/ssot/secrets.md` | 密钥 SSOT |
| `docs/ssot/vars.md` | 变量定义 |
| `.github/actions/terraform-setup/` | CI 变量注入 |
| `1.bootstrap/2.atlantis.tf` | Atlantis Pod env |
| `atlantis.yaml` | GitOps 配置 |
