# Test 环境部署 SOP

**环境**: Test (PR 预览)  
**域名**: x-test.truealpha.club, api-x-test.truealpha.club，PR 预览使用 `x-test-*.truealpha.club`  
**通用流程**: 见 `docs/deployment-sop.md`（Layer 1/2/3 三层模型）

**进度状态**: 见 `terraform/envs/test/STATUS.md`

---

## 📝 环境特定配置（按 Layer 1/2/3）

### Layer 1：全局平台
- Dokploy + Infisical 已在全局层完成后，再执行环境层。  
- GitHub Secrets 仅存访问凭据：SSH、Cloudflare、Infisical MI，不存业务值。

### Layer 2：共享基础设施（Terraform）

**文件**: `terraform/envs/test/terraform.tfvars`（示例）

```hcl
environment = "test"
project_name = "truealpha"
domain = "truealpha.club"

# VPS / Bootstrap
vps_ip = "<test-vps-ip>"
vps_count = 0
enable_vps_bootstrap = true
ssh_user = "<user>"

# Cloudflare
cloudflare_api_token = "<from-github-secret>"
cloudflare_zone_id = "<from-github-secret>"

# Tags
tags = {
  Environment = "test"
  ManagedBy   = "terraform"
  Purpose     = "pr-preview"
}
```

### Layer 3：应用层（Dokploy/Compose）

- 使用 Dokploy Project: `truealpha-test-{pr}`（按 PR 编号动态创建）。  
- 环境变量唯一来源 Infisical（项目: truealpha，环境: test），PR 动态变量通过 CI 注入/覆写。  
- 域名：`x-test-{pr}.truealpha.club` / `api-x-test-{pr}.truealpha.club`（由 Cloudflare + Traefik 路由）。

### GitHub Secrets（凭据类）

```yaml
# 特定于 test
SSH_HOST: <test-vps-ip>
SSH_USER: <user>
SSH_PRIVATE_KEY: <test-ssh-key>

# Infisical (Machine Identity)
INFISICAL_PROJECT_ID: <project-id>
# 环境: test
```

### 环境变量 (Infisical) — 唯一源

**项目**: truealpha  
**环境**: test  
**变量数**: 81 (从 `secrets/.env.example`)

**关键配置**（示例）:
```bash
PEG_ENV=test
DOMAIN=x-test.truealpha.club
POSTGRES_HOST=postgres
REDIS_HOST=redis
SIGNOZ_ENDPOINT=http://signoz-otel-collector:4317
```

---

## 🚀 首次部署步骤

1. **配置 GitHub Secrets（一次性）**  
   填写 SSH/Cloudflare/Infisical MI 三元组。

2. **配置 Infisical（一次性，唯一源）**  
   - 项目: truealpha  
   - 环境: test  
   - 导入 81 个变量，创建 Machine Identity。

3. **执行 Terraform（Layer 2）**  
   ```bash
   cd terraform/envs/test
   terraform init
   terraform plan
   terraform apply
   ```

4. **部署应用（Layer 3）**  
   - 通过 CI/PR 触发 PR 预览部署  
   - 或手动 `./scripts/deploy/deploy.sh test`

5. **验证**  
   - `dig x-test.truealpha.club`  
   - `curl -I https://x-test.truealpha.club`  
   - `curl https://api-x-test.truealpha.club/graphql`

---

## 🔄 日常/PR 预览操作

- PR 打开 → CI 创建 `truealpha-test-{pr}` Project + 域名  
- PR 更新 → 重新部署对应 Project  
- PR 关闭 → 自动清理 Project/域名（CI 逻辑）

---

## ✅ 验证清单

- [ ] DNS/SSL：x-test.{domain} / api-x-test.{domain} 可访问  
- [ ] 应用健康：`/graphql` 返回 200  
- [ ] 观测：SigNoz 有 traces/metrics（如启用）  
- [ ] 清理：PR 关闭后资源清理成功

---

## 🔗 相关资源

- **通用SOP**: `docs/deployment-sop.md`  
- **环境状态**: `terraform/envs/test/STATUS.md`  
- **整体进度**: `docs/PROGRESS.md`  
- **Terraform配置**: `terraform/envs/test/`  
- **Compose配置**: `compose/test.yml`
