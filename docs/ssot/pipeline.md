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

| 组件 | 等待 | 状态 | 超时 |
|------|------|------|------|
| Vault | PostgreSQL | ✅ | 120s |
| Casdoor | PostgreSQL | ✅ | 120s |
| Portal-Auth | Casdoor | ✅ | 120s |
| L3 PostgreSQL | Platform PG | ✅ | 120s |
| **L3 Redis** | **Vault KV** | **✅** | **120s** |
| **L3 ClickHouse** | **Vault KV** | **✅** | **120s** |
| **L3 ArangoDB Operator** | **Vault KV** | **✅** | **120s** |

---

## 3. 验证清单

### CI 自动检查 (terraform-plan.yml)

```bash
# L1 Bootstrap
cd 1.bootstrap
terraform fmt -check -recursive
terraform init -backend=false
terraform validate

# L2 Platform
cd ../2.platform
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

**必需环境变量**:
- `VAULT_ROOT_TOKEN` - Vault provider 认证
- `VAULT_ADDR` - Vault 地址
- `CLOUDFLARE_API_TOKEN` - Cloudflare provider

### L3 Data Services 健康检查矩阵

| 组件 | precondition | initContainer | validation | lifecycle | timeout |
|------|--------------|---------------|------------|-----------|----------|
| PostgreSQL | ✅ Platform PG ready | ✅ 120s | ✅ password | ✅ prevent_destroy | 300s |
| **Redis** | **✅ Vault ready** | **✅ 120s** | **❌** | **✅ prevent_destroy** | **300s** |
| **ClickHouse** | **✅ Vault ready** | **✅ 120s** | **❌** | **✅ prevent_destroy** | **300s** |
| **ArangoDB** | **✅ Vault ready** | **❌** | **❌** | **✅ prevent_destroy** | **300s** |

**待补齐项**:
- [ ] 为新数据库添加 `validation` 块验证密码非空
- [ ] ArangoDB Operator 添加 `initContainer` 等待命名空间创建

### Terraform Provider 初始化检查

```bash
# 检查 provider 版本一致性
terraform providers lock \
  -platform=linux_amd64 \
  -platform=darwin_amd64 \
  -platform=darwin_arm64

# 验证 .terraform.lock.hcl 提交到 Git
git status .terraform.lock.hcl
```

### Namespace 环境隔离检查

```bash
# L3 必须使用 per-env namespace
grep 'data-${terraform.workspace}' 3.data/*.tf

# 验证输出使用动态生成
grep 'local.namespace_name' 3.data/*.tf
```

---

## 4. 部署流程

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

### 变量缺失

```
Error: No value for required variable
```

**检查**：
1. GitHub Secrets 是否存在
2. CI workflow 是否传递
3. Atlantis Pod env 是否有

### Vault Token 错误

```
Error: failed to lookup token, err=invalid character '<' looking for beginning of value

with vault_mount.kv,
on 6.vault-database.tf line 16
```

**原因**: `VAULT_ROOT_TOKEN` 环境变量未设置或无效

**检查步骤**:
1. **GitHub Secrets 存在性**:
   ```bash
   gh secret list --repo wangzitian0/infra | grep VAULT_ROOT_TOKEN
   ```

2. **CI Workflow 传递**:
   查看 `.github/workflows/terraform-plan.yml`:
   ```yaml
   env:
     VAULT_TOKEN: ${{ secrets.VAULT_ROOT_TOKEN }}  # ✅ 必须有
     VAULT_ADDR: https://secrets.{domain}         # ✅ 必须有
   ```

3. **Vault 可访问性**:
   ```bash
   curl -I https://secrets.{domain}/v1/sys/health
   # 应返回 200 OK (sealed) 或 503 (sealed)
   ```

**修复**:
- Option A: 更新 GitHub Secret
  ```bash
  gh secret set VAULT_ROOT_TOKEN --body "$(op read 'op://Infrastructure/Vault Root Token/credential')" --repo wangzitian0/infra
  ```
  
- Option B: CI 跳过 Vault provider
  ```hcl
  # 2.platform/providers.tf
  provider "vault" {
    # CI 时使用 fake token (仅 validate 语法)
    address = var.vault_address != "" ? var.vault_address : "http://fake.local:8200"
    token   = var.vault_root_token != "" ? var.vault_root_token : "fake-token-for-ci"
  }
  ```

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
