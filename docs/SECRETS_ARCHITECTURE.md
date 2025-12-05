# Secrets Management Architecture

## Overview

Layered secrets management approach using GitHub Secrets for bootstrap and Infisical for application secrets.

## Architecture Layers（phase 内无依赖）

```
┌─────────────────────────────────────────┐
│ GitHub Secrets (Bootstrap Layer)        │
│ - VPS SSH Key                           │
│ - R2 Credentials (State Backend)        │
│ - 可选 k3s 参数                         │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ Phase 0.x: k3s + Infisical              │
│ - k3s via Terraform + SSH               │
│ - Infisical online → 密钥集中存储       │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ Phase 1.x: 平台入口与底座               │
│ - 平台 PostgreSQL（Infisical/Kubero）    │
│ - Kubernetes Dashboard                  │
│ - Kubero + Kubero UI                    │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ Phase 2.x: 业务数据层                   │
│ - 应用 PostgreSQL（业务库，独立于平台库）│
│ - Neo4j / Redis / ClickHouse            │
│ - 密码由 Terraform 生成并写入 Infisical  │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│ Phase 3.x: 观测/分析                    │
│ - SigNoz / PostHog（凭据来自 Infisical） │
└─────────────────────────────────────────┘
```

## Phase Breakdown

### Phase 0.x：k3s + Infisical

**Secrets Required（GitHub Secrets 层）：**
- VPS SSH Key（`VPS_SSH_KEY`）
- R2 凭据（Terraform state backend）
- 可选 k3s 安装参数（`K3S_*` 变量）

**Purpose:**
- 通过 Terraform + SSH 装好 k3s，拿到 kubeconfig
- 将 Infisical 跑起来；完成后所有新密码写入 Infisical

**Infisical 组件：**
1. **Infisical Backend**
   - Encryption/JWT secrets：Terraform 随机生成（`random_id`）
   - Admin：部署后在 UI 手动创建
2. **MongoDB (Embedded)**
   - Root/User 密码：Terraform `random_password`
   - 20Gi PVC
3. **Redis (Embedded)**
   - 无鉴权（ClusterIP 内部访问），10Gi PVC
4. **Mailhog (Embedded)**
   - Dev-only，无鉴权

### Phase 1.x：平台入口 + PaaS

**Purpose:** 平台能力与访问入口。平台 PostgreSQL 专供 Infisical/Kubero，不与业务库混用。

**Components & Secrets:**
- 平台 PostgreSQL：密码由 Terraform 生成或 GitHub Secret 提供 → 写入 Infisical
- Kubernetes Dashboard：使用 SA token（无额外密码）
- Kubero Controller + Kubero UI：使用 Infisical 存储访问令牌/初始密码

### Phase 2.x：业务数据服务

**Purpose:** 业务侧数据库与缓存，独立于平台库。

**Components:**
- 应用 PostgreSQL（业务库）
- Neo4j
- Redis
- ClickHouse

**Pattern:** Terraform 生成密码 → 写入 Infisical Provider → Helm 部署引用（`set_sensitive`）→ 运行时可从 Infisical 读取。

**Prerequisites:** Phase 0.x 完成；Infisical workspace/API token 已配置。

### Phase 3.x：观测/分析

**Purpose:** SigNoz + PostHog，凭据同样由 Terraform 写入 Infisical；phase 内可并行。

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
# Infisical Provider（写入平台/业务密码）
INFISICAL_API_TOKEN=<api-token>
INFISICAL_WORKSPACE_ID=<workspace-id>
```

> 平台 PostgreSQL（Infisical/Kubero 用）与业务 PostgreSQL 分离，密码均写入 Infisical，不再新增 GitHub Secrets。

## Deployment Instructions

### Step 1: Phase 0.x（k3s + Infisical）

```bash
cd terraform
terraform init \
  -backend-config="bucket=$R2_BUCKET" \
  -backend-config="endpoints={s3=\"https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com\"}"

terraform apply -target="null_resource.k3s_server" -var-file="staging.tfvars"               # k3s
terraform apply -target="module.phases.helm_release.postgresql" -var-file="staging.tfvars"  # 平台 PG（Infisical/Kubero）
terraform apply -target="module.phases.helm_release.infisical" -var-file="staging.tfvars"
```

### Step 2: Phase 1.x（管理入口 + PaaS）

```bash
terraform apply -var-file="staging.tfvars" -target="module.phases.helm_release.kubernetes_dashboard"
# Kubero/Kubero UI：待后续模块补充
```

### Step 3: Phase 2.x（业务数据层，待补充模块）

```bash
# 模块落地后按需 target：
# terraform apply -var-file="staging.tfvars" -target="module.postgresql_app,module.neo4j,module.redis,module.clickhouse"
```

### Step 4: Phase 3.x（观测/分析，待补充模块）

```bash
# 模块落地后按需 target：
# terraform apply -var-file="staging.tfvars" -target="module.signoz,module.posthog"
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
1. 区分平台库 vs 业务库：
   - 平台 PostgreSQL（Infisical/Kubero）：查看 Infisical 中的对应 secret。
   - 业务 PostgreSQL：查看 Infisical 中的业务库密码。
2. 如需旋转密码，使用 Terraform 重新生成并写回：
   ```bash
   terraform apply -var-file="staging.tfvars" -target="module.phases.helm_release.postgresql"   # 平台库
   # 业务库落地后，使用对应模块 target
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
