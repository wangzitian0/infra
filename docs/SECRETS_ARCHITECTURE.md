# Secrets Management Architecture

## Overview

Layered secrets management approach using GitHub Secrets for bootstrap and Infisical for application secrets.

## Architecture Layers

```
┌─────────────────────────────────────────┐
│   GitHub Secrets (Bootstrap Layer)      │
│  - VPS SSH Key, R2 Credentials          │
│  - 初始 k3s/Infisical 安装参数           │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Phase 0.x: k3s + Infisical             │
│ - k3s via Terraform + SSH               │
│ - Infisical online → 后续密码都存这里   │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Phase 1.x: Access & PaaS (parallel)    │
│ - Kubernetes Dashboard                  │
│ - Kubero + Kubero UI                    │
│ - 平台 PostgreSQL                       │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Phase 2.x: Data Services (parallel)    │
│ - PostgreSQL / Neo4j / Redis / ClickHouse│
│ - 密码由 Terraform 生成并同步到 Infisical │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│  Phase 3.x: Observability & Analytics   │
│ - SigNoz、PostHog（凭据来自 Infisical） │
└─────────────────────────────────────────┘
```

## Phase Breakdown

### Phase 0.x: k3s + Infisical

**Secrets Required（GitHub Secrets 层）：**
- VPS SSH Key（`VPS_SSH_KEY`）
- R2 凭据（Terraform state backend）
- 可选 k3s 安装参数（`K3S_*` 变量）

**Purpose:**
- 通过 Terraform + SSH 装好 k3s，拿到 kubeconfig
- 将 Infisical 跑起来；完成后所有新密码都写入 Infisical（由 Terraform 生成或手动录入）

**Infisical 组件：**
1. **Infisical Backend**
   - Encryption/JWT secrets：Terraform 随机生成（`random_id`）
   - Admin 账号：部署后在 UI 手动创建
2. **MongoDB (Embedded)**
   - Root/User 密码：Terraform `random_password`
   - 存储：20Gi PVC
3. **Redis (Embedded)**
   - 无鉴权，ClusterIP 内部访问
   - 存储：10Gi PVC
4. **Mailhog (Embedded)**
   - Dev-only，无鉴权

### Phase 1.x: Kubernetes Dashboard + Kubero Stack

**Purpose:** 集群访问入口与 PaaS 能力（phase 内可并行）。

**Components & Secrets:**
- Kubernetes Dashboard：无额外密码（SA token）
- Kubero Controller + Kubero UI：使用 Infisical 存储访问令牌/初始密码
- 平台 PostgreSQL（Kubero/控制面数据库）：密码由 Terraform 生成并同步到 Infisical

### Phase 2.x: 数据服务（PostgreSQL/Neo4j/Redis/ClickHouse）

**Strategy:** Terraform 生成密码 → 同步到 Infisical → 部署服务。无内部依赖，可按需选择。

**Workflow:**
1. Terraform 生成随机密码（`random_password`）
2. Terraform 通过 Infisical Provider 创建/更新对应 secret
3. Helm 部署使用该密码（`set_sensitive`）
4. 应用运行时从 Infisical 读取（可选）

**Example (Redis):**
```hcl
# Generate password
resource "random_password" "redis" {
  length  = 32
  special = true
}

# Store in Infisical
resource "infisical_secret" "redis_password" {
  workspace_id = var.infisical_workspace_id
  secret_name  = "REDIS_PASSWORD"
  secret_value = random_password.redis.result
}

# Deploy Redis with password
resource "helm_release" "redis" {
  # ... chart config ...
  set_sensitive {
    name  = "auth.password"
    value = random_password.redis.result
  }
}
```

**Prerequisites:**
- Phase 0.x 完成（Infisical 可用）
- 已在 Infisical UI 创建 workspace + API token
- GitHub Secrets 中配置 `INFISICAL_API_TOKEN`、`INFISICAL_WORKSPACE_ID`

### Phase 3.x: Observability & Product Analytics

**Purpose:** SigNoz + PostHog，密码同样由 Terraform 写入 Infisical；phase 内可并行。

**Prerequisites:** Phase 0.x 完成；若走域名/Ingress，需配合 Phase 1.x 的入口与 DNS。

## GitHub Secrets Required

### Phase 0.x（Bootstrap）
```bash
# VPS Access
VPS_HOST=<ip-or-domain>
VPS_SSH_KEY=<private-key>
VPS_USER=root  # optional
VPS_SSH_PORT=22  # optional

# Terraform State Backend (R2)
AWS_ACCESS_KEY_ID=<r2-access-key>
AWS_SECRET_ACCESS_KEY=<r2-secret-key>
R2_BUCKET=<bucket-name>
R2_ACCOUNT_ID=<cloudflare-account-id>

# k3s Configuration (optional)
K3S_CLUSTER_NAME=truealpha-k3s
K3S_CHANNEL=stable
K3S_VERSION=
```

### 完成 Phase 0.x 之后
```bash
# Infisical Provider
INFISICAL_API_TOKEN=<api-token>
INFISICAL_WORKSPACE_ID=<workspace-id>
```

**说明：** Phase 1.x/2.x/3.x 的服务密码统一写入 Infisical，不再新增 GitHub Secrets。

## Deployment Instructions

### Step 1: Phase 0.x（k3s + Infisical）

```bash
cd terraform
terraform init \
  -backend-config="bucket=$R2_BUCKET" \
  -backend-config="endpoints={s3=\"https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com\"}"

terraform apply -target="module.k3s" -var-file="staging.tfvars"
terraform apply -target="module.infisical" -var-file="staging.tfvars"
```

### Step 2: Phase 1.x（Kubernetes Dashboard + Kubero Stack）

```bash
terraform apply -var-file="staging.tfvars" -target="module.kubernetes_dashboard"
terraform apply -var-file="staging.tfvars" -target="module.kubero,module.kubero_ui"
terraform apply -var-file="staging.tfvars" -target="module.platform_postgresql"
```

### Step 3: Phase 2.x（数据服务，按需挑选 target）

```bash
terraform apply -var-file="staging.tfvars" -target="module.postgresql_app,module.neo4j,module.redis,module.clickhouse"
```

### Step 4: Phase 3.x 或全量 Apply

```bash
terraform apply -var-file="staging.tfvars" -target="module.signoz,module.posthog"
# 或直接全量：
terraform apply -var-file="staging.tfvars"
```

## Access Infisical UI

After Phase 0.x deployment:

```bash
# Port forward to access Infisical
kubectl -n iac port-forward svc/infisical-backend 8080:8080

# Open in browser: http://localhost:8080
```

**First-time setup:**
1. Create admin account
2. Create workspace (e.g., "truealpha-staging")
3. Generate API token (Settings → API Tokens)
4. Add token to GitHub Secrets as `INFISICAL_API_TOKEN`
5. Add workspace ID to GitHub Secrets as `INFISICAL_WORKSPACE_ID`

## Disaster Recovery

### Scenario: Lost Infisical Data

**Recovery Steps:**
1. Check Terraform state for passwords:
   ```bash
   terraform state show random_password.infisical_mongodb_root
   terraform state show random_password.infisical_mongodb_user
   ```

2. MongoDB data persists in PVC (unless deleted)

3. If PVC lost, re-apply Infisical resources:
   ```bash
   terraform apply -target=helm_release.infisical
   ```

### Scenario: Lost PostgreSQL Password

**Recovery Steps:**
1. 在 Infisical 查找对应的 PostgreSQL 密码（平台库或业务库）。
2. 若需旋转，使用 Terraform 重新生成并写回：
   ```bash
   terraform apply -var-file="staging.tfvars" -target="module.postgresql_app"
   ```

## Security Best Practices

### Do's
✅ Use GitHub Secrets for bootstrap credentials
✅ Use Terraform `random_password` for service passwords
✅ Rotate passwords via Terraform re-apply
✅ Use Infisical for Phase 2.x+ services
✅ Keep sensitive values in Terraform state (stored in R2)
✅ Use strong passwords (32+ characters, mixed case, special chars)

### Don'ts
❌ Hardcode passwords in code
❌ Commit secrets to git
❌ Use default passwords (`CHANGE_ME`)
❌ Share secrets via insecure channels
❌ Skip rotation of compromised secrets
❌ Store secrets in plaintext files

## Future Improvements

### Phase 2.x Implementation
- [ ] Add Infisical Terraform provider
- [ ] Implement password generation + sync pattern
- [ ] Configure applications to read from Infisical

### Phase 3.x+ Integration
- [ ] External Secrets Operator (auto-sync to k8s secrets)
- [ ] Vault integration (enterprise option)
- [ ] Secret rotation automation

### Observability
- [ ] Audit logging for secret access
- [ ] Alerting on secret changes
- [ ] Compliance reporting

## References

- [Infisical Terraform Provider](https://registry.terraform.io/providers/Infisical/infisical/latest/docs)
- [Terraform Random Provider](https://registry.terraform.io/providers/hashicorp/random/latest/docs)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Infisical Documentation](https://infisical.com/docs)
