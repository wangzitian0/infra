# Staging 环境部署 SOP

**环境**: Staging (预发布)  
**域名**: x-staging.truealpha.club, api-x-staging.truealpha.club  
**VPS**: 103.214.23.41  
**通用流程**: 见 `docs/deployment-sop.md`（Layer 1/2/3 三层模型）

**进度状态**: 见 `terraform/envs/staging/STATUS.md`

---

## 📝 环境特定配置（按 Layer 1/2/3）

### Layer 1：全局平台（仅此处一次性安装/变更）
- 复用 `docs/env.d/iac_sop.md`：单台 VPS 完成 Dokploy + Infisical（Machine Identity），完成后 test/prod 复用，不再重装。  
- GitHub Secrets 仅存 Infisical MI 三元组；SSH/Cloudflare 等访问凭据也放在 Infisical。

### Layer 2：共享基础设施（Terraform）

**文件**: `terraform/envs/staging/terraform.tfvars`

```hcl
environment = "staging"
project_name = "truealpha"
domain = "truealpha.club"

# VPS
vps_ip = "103.214.23.41"
vps_count = 0
enable_vps_bootstrap = true
ssh_user = "prod"

# Cloudflare  
cloudflare_api_token = "<from-github-secret>"
cloudflare_zone_id = "<from-github-secret>"

# Tags
tags = {
  Environment = "staging"
  ManagedBy   = "terraform"
  Purpose     = "pre-production-testing"
}
```

### Layer 3：应用层（Dokploy/Compose）

- 所有业务变量从 **Infisical** 拉取（项目: truealpha，环境: staging），不在 GitHub Secrets。
- Dokploy Project: `truealpha-staging`，引用 compose/staging.yml 生成的栈。
- 域名路由：Traefik / Cloudflare 终结，证书由 Cloudflare/Traefik 管理。

### GitHub Secrets（仅 Infisical MI 三元组）

```yaml
INFISICAL_CLIENT_ID: <machine-identity-id>
INFISICAL_CLIENT_SECRET: <machine-identity-secret>
INFISICAL_PROJECT_ID: <project-id>  # 环境: staging
```

### 环境变量 / 凭据 (Infisical) — 唯一源

**项目**: truealpha  
**环境**: staging  
**变量数**: 81 (从 `secrets/.env.example`)

**关键配置**:
```bash
PEG_ENV=staging
DOMAIN=x-staging.truealpha.club

# Database
NEO4J_URI=bolt://neo4j:7687
POSTGRES_HOST=postgres
REDIS_HOST=redis

# Observability
SIGNOZ_ENDPOINT=http://signoz-otel-collector:4317
POSTHOG_HOST=https://app.posthog.com

# Access
SSH_PRIVATE_KEY=<...>
SSH_USER=prod
SSH_HOST=103.214.23.41
CLOUDFLARE_API_TOKEN=<...>
CLOUDFLARE_ZONE_ID=<...>
```

---

## 🚀 首次部署步骤

### 1. 复用全局层
- 确认已完成 `iac_sop.md`（Dokploy+Infisical+MI 安装完毕，GitHub Secrets 已填 MI 三元组）。

### 2. 配置 Infisical (一次性，唯一源)

```bash
# 1. 登录自托管 Infisical (UI)
# 2. 创建项目 "truealpha"
# 3. 创建环境 "staging"
# 4. 导入变量（来自 secrets/.env.example）
cp secrets/.env.example staging-secrets.env
# 编辑 staging-secrets.env 填充实际值
# 5. 在 Infisical UI 中批量导入
# 6. 创建 Machine Identity 获取凭证
```

### 3. Layer 2：Terraform

```bash
cd terraform/envs/staging
terraform init
terraform plan
terraform apply
```

### 4. Layer 3：部署应用（全自动，无 UI）

```bash
./scripts/deploy/export-secrets.sh staging   # 从 Infisical 拉取全部变量
./scripts/deploy/deploy.sh staging           # 通过 Dokploy API/CLI 应用 compose
```

### 5. 验证部署

```bash
# 等待 5-10 分钟后验证
curl -I https://x-staging.truealpha.club
curl https://api-x-staging.truealpha.club/graphql

# 检查所有服务
ssh prod@103.214.23.41
docker compose -p truealpha-staging ps
```

---

## 🔄 日常部署

### 代码更新

```bash
# 开发完成后
git push origin main
# 自动部署到 staging
# 预计 5 分钟完成
```

### 配置更新

```bash
# 修改 compose/staging.yml
vim compose/staging.yml
git push origin main
# 自动重新部署
```

### 环境变量更新

```bash
# 1. 在 Infisical 中更新变量（唯一源）
# 2. 手动触发部署 (GitHub → Actions → Deploy Staging → Run workflow)
```

---

## ✅ 验证清单

### 基础设施

- [ ] DNS: `dig x-staging.truealpha.club` 返回 103.214.23.41
- [ ] SSL: `curl -I https://x-staging.truealpha.club` 返回 200
- [ ] 防火墙: 仅 SSH/HTTP/HTTPS 开放

### 应用服务

- [ ] Backend API: https://api-x-staging.truealpha.club/graphql
- [ ] Neo4j: 容器内部可访问
- [ ] PostgreSQL: 容器内部可访问
- [ ] Redis: 容器内部可访问
- [ ] Celery Worker: 运行中
- [ ] Celery Beat: 运行中
- [ ] Flower: http://x-staging.truealpha.club:5555 (仅内网)
- [ ] Traefik: 路由正常

### 可观测性

- [ ] SigNoz: 接收 traces/metrics/logs
- [ ] PostHog: 事件上报正常
- [ ] Docker logs: 无错误日志

---

## 🎯 Staging 特定用途

### 预发布验证

1. 功能验证 - 新功能完整测试
2. 性能验证 - 压力测试
3. 数据迁移验证 - 生产数据快照测试
4. 集成验证 - 第三方服务集成

### 演示环境

- 对外演示新功能
- 客户 UAT 测试
- 合作伙伴集成测试

### 长期运行

- Staging 环境保持长期运行
- 不会自动清理（与 test PR 预览不同）
- 定期同步生产数据（脱敏）

---

## 🚨 故障处理

### 常见问题

**问题1**: 服务启动失败
```bash
ssh prod@103.214.23.41
cd /opt/truealpha/infra
docker compose -p truealpha-staging logs backend
# 检查环境变量和依赖服务
```

**问题2**: DNS 解析失败
```bash
# 检查 Cloudflare DNS 记录
# 等待 DNS 传播 (最多 5 分钟)
```

**问题3**: Infisical 导出失败
```bash
# 验证 Machine Identity 凭证有效
# 检查网络连接
```

---

## 📊 监控仪表板

### GitHub Actions
- URL: https://github.com/wangzitian0/infra/actions
- 查看部署历史和日志

### SigNoz (部署后)
- URL: http://x-staging.truealpha.club:3301
- Traces, Metrics, Logs

### PostHog (部署后)
- URL: https://app.posthog.com
- 事件分析和用户行为

---

## 🔗 相关资源

- **通用SOP**: `docs/deployment-sop.md`
- **环境状态**: `terraform/envs/staging/STATUS.md`
- **整体进度**: `docs/PROGRESS.md`
- **Terraform配置**: `terraform/envs/staging/`
- **Compose配置**: `compose/staging.yml`

---

## 📅 维护计划

### 每周

- [ ] 检查服务健康状态
- [ ] 查看错误日志
- [ ] 验证备份 (如配置)

### 每月

- [ ] 同步生产数据到 staging (脱敏)
- [ ] 更新依赖和安全补丁
- [ ] 清理旧日志和数据

### 每季度

- [ ] 负载测试
- [ ] 灾难恢复演练
- [ ] 安全审计
