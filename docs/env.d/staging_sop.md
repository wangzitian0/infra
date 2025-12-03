# Staging 环境部署 SOP

**环境**: Staging (预发布)  
**域名**: x-staging.truealpha.club, api-x-staging.truealpha.club  
**VPS**: 103.214.23.41  
**通用流程**: 见 `docs/deployment-sop.md`

**进度状态**: 见 `terraform/envs/staging/STATUS.md`

---

## 📝 环境特定配置

### Terraform 变量

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

### GitHub Secrets

```yaml
# 特定于 staging
SSH_HOST: 103.214.23.41
SSH_USER: prod
SSH_PRIVATE_KEY: <staging-ssh-key>

# Infisical
INFISICAL_PROJECT_ID: <project-id>
# 环境: staging
```

### 环境变量 (Infisical)

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
```

---

## 🚀 首次部署步骤

### 1. 配置 GitHub Secrets (一次性)

在 `github.com/wangzitian0/infra/settings/secrets/actions` 添加：
- SSH_HOST, SSH_USER, SSH_PRIVATE_KEY
- CLOUDFLARE_API_TOKEN, CLOUDFLARE_ZONE_ID
- INFISICAL_CLIENT_ID, INFISICAL_CLIENT_SECRET, INFISICAL_PROJECT_ID

### 2. 配置 Infisical (一次性)

```bash
# 1. 登录 https://app.infisical.com
# 2. 创建项目 "truealpha"
# 3. 创建环境 "staging"
# 4. 导入变量
cp secrets/.env.example staging-secrets.env
# 编辑 staging-secrets.env 填充实际值
# 5. 在 Infisical UI 中批量导入
# 6. 创建 Machine Identity 获取凭证
```

### 3. 执行部署

```bash
# 推送代码触发自动部署
git push origin main

# 或手动触发
# GitHub → Actions → Deploy Staging → Run workflow
```

### 4. 验证部署

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
# 1. 在 Infisical 中更新变量
# 2. 手动触发部署
# GitHub → Actions → Deploy Staging → Run workflow
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
