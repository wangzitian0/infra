# Production 环境部署 SOP

**环境**: Production  
**域名**: truealpha.club, api.truealpha.club  
**通用流程**: 见 `docs/deployment-sop.md`（Layer 1/2/3 三层模型）

**进度状态**: 见 `terraform/envs/prod/STATUS.md`

---

## 📝 环境特定配置（按 Layer 1/2/3）

### Layer 1：全局平台
- 已在 staging 阶段单台 VPS 完成 Dokploy + Infisical；生产仅复用，不重装。  
- GitHub Secrets 仅存 Infisical MI 三元组；SSH/Cloudflare 等访问凭据也放在 Infisical。

### Layer 2：共享基础设施（Terraform）

**文件**: `terraform/envs/prod/terraform.tfvars`（示例）

```hcl
environment = "prod"
project_name = "truealpha"
domain = "truealpha.club"

# VPS / Bootstrap
vps_ip = "<prod-vps-ip>"
vps_count = 0
enable_vps_bootstrap = true
ssh_user = "<user>"

# Cloudflare
cloudflare_api_token = "<from-github-secret>"
cloudflare_zone_id = "<from-github-secret>"

# Tags
tags = {
  Environment = "prod"
  ManagedBy   = "terraform"
  Purpose     = "production"
}
```

### Layer 3：应用层（Dokploy/Compose）

- Dokploy Project: `truealpha-prod`（可在独立 VPS/Project 物理隔离）。  
- 环境变量唯一来源 Infisical（项目: truealpha，环境: prod）；GitHub Secrets 不存业务值。  
- 域名：`truealpha.club` / `api.truealpha.club`，Cloudflare + Traefik 终结。

### GitHub Secrets（仅 Infisical MI 三元组）

```yaml
INFISICAL_CLIENT_ID: <machine-identity-id>
INFISICAL_CLIENT_SECRET: <machine-identity-secret>
INFISICAL_PROJECT_ID: <project-id>  # 环境: prod
```

### 环境变量 / 凭据 (Infisical) — 唯一源

**项目**: truealpha  
**环境**: prod  
**变量数**: 81 (从 `secrets/.env.example`)

**关键配置**（示例）:
```bash
PEG_ENV=prod
DOMAIN=truealpha.club
POSTGRES_HOST=postgres
REDIS_HOST=redis
SIGNOZ_ENDPOINT=http://signoz-otel-collector:4317

# Access / Infra
SSH_PRIVATE_KEY=<...>
SSH_USER=<user>
SSH_HOST=<prod-vps-ip>
CLOUDFLARE_API_TOKEN=<...>
CLOUDFLARE_ZONE_ID=<...>
```

---

## 🚀 首次部署步骤

1. **复用全局层**  
   - 确认已完成 `iac_sop.md`（Dokploy+Infisical+MI 安装完毕，GitHub Secrets 已填 MI 三元组）。

2. **配置自托管 Infisical（一次性，唯一源）**  
   - 项目: truealpha  
   - 环境: prod  
   - 导入 81 个变量，创建 Machine Identity。

3. **执行 Terraform（Layer 2）**  
   ```bash
   cd terraform/envs/prod
   terraform init
   terraform plan
   terraform apply
   ```

4. **部署应用（Layer 3，全自动，无 UI）**  
   - CI/CD 自动部署（Dokploy API/CLI 应用 compose）或手动  
   - `./scripts/deploy/export-secrets.sh prod && ./scripts/deploy/deploy.sh prod`

5. **验证**  
   - `dig truealpha.club`  
   - `curl -I https://truealpha.club`  
   - `curl https://api.truealpha.club/graphql`

---

## 🔄 日常操作

- 代码更新 → CI/CD 部署  
- 配置更新 → 修改 compose/prod.yml + 触发部署  
- 变量更新 → Infisical 更新后触发部署  
- 备份/恢复 → 参考 runbooks/operations.md（数据库/配置备份）

---

## ✅ 验证清单

- [ ] DNS/SSL：truealpha.club / api.truealpha.club 可访问  
- [ ] 应用健康：`/graphql` 返回 200  
- [ ] 观测：SigNoz 有 traces/metrics（如启用）  
- [ ] 备份：数据库备份策略生效

---

## 🔗 相关资源

- **通用SOP**: `docs/deployment-sop.md`  
- **环境状态**: `terraform/envs/prod/STATUS.md`  
- **整体进度**: `docs/PROGRESS.md`  
- **Terraform配置**: `terraform/envs/prod/`  
- **Compose配置**: `compose/prod.yml`
