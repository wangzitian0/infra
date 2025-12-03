# Staging 环境部署计划

**目标**: 通过部署 staging 环境，建立完整的 GitHub CI 自动部署流程

**策略**: End-to-End，从基础设施到应用部署全流程打通

---

## 🎯 部署路径

```
GitHub Actions → Terraform (DNS) → VPS (Docker/Dokploy) → 应用部署 → 验证
```

---

## 📋 阶段 1: 基础设施准备 (Terraform 自动化)

### 方案 A: Terraform 自动化 (推荐)

使用 Terraform `vps-bootstrap` 模块通过 SSH 自动安装。

**配置**: `terraform/envs/staging/terraform.tfvars`

```hcl
environment = "staging"
vps_ip = "103.214.23.41"
vps_count = 0

# 启用自动化 bootstrap
enable_vps_bootstrap = true
ssh_user = "prod"
ssh_private_key = file("~/.ssh/id_rsa")  # 或通过环境变量

# Cloudflare
cloudflare_api_token = "<token>"
cloudflare_zone_id = "<zone-id>"
```

**执行**:
```bash
cd terraform/envs/staging
terraform init
terraform apply
```

**自动完成**:
- ✅ 安装 Docker
- ✅ 安装 Dokploy
- ✅ 配置 UFW 防火墙 (SSH/HTTP/HTTPS)
- ✅ 安装 fail2ban
- ✅ 验证所有安装

### 方案 B: 手动执行 (备选)

如果不想使用 Terraform provisioner：

```bash
ssh prod@103.214.23.41

# 安装 Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# 安装 Dokploy
curl -sSL https://dokploy.com/install.sh | sudo sh

# 配置防火墙
sudo apt-get install -y ufw fail2ban
sudo ufw allow ssh && sudo ufw allow 80/tcp && sudo ufw allow 443/tcp
sudo ufw enable
```

### 1.2 Secrets 管理
- [ ] 注册 Infisical Cloud (https://app.infisical.com)
- [ ] 创建项目 "truealpha-infra"
- [ ] 创建环境: staging
- [ ] 从 `secrets/.env.example` 复制并填充所有 81 个变量

**关键变量**:
```
# Database
NEO4J_PASSWORD=<generate>
POSTGRES_PASSWORD=<generate>
REDIS_PASSWORD=<generate>

# Backend
JWT_SECRET=<generate>
OPENAI_API_KEY=<your-key>

# Observability
SIGNOZ_ENDPOINT=http://signoz:4317
```

### 1.3 GitHub Secrets 配置
在 GitHub Repo Settings → Secrets 添加：

- [ ] `INFISICAL_CLIENT_ID` - Infisical Machine Identity
- [ ] `INFISICAL_CLIENT_SECRET` - Infisical Secret
- [ ] `INFISICAL_PROJECT_ID` - Project ID
- [ ] `SSH_PRIVATE_KEY` - VPS SSH 私钥
- [ ] `SSH_USER` - prod
- [ ] `SSH_HOST` - 103.214.23.41
- [ ] `CLOUDFLARE_API_TOKEN` - 已有

---

## 📋 阶段 2: Terraform DNS (GitHub Actions)

### 2.1 创建 staging 环境配置

**文件**: `terraform/envs/staging/terraform.tfvars`

```hcl
environment = "staging"
project_name = "truealpha"
domain = "truealpha.club"

# Cloudflare
cloudflare_api_token = "<from-secret>"
cloudflare_zone_id = "<zone-id>"

# VPS (manual)
vps_ip = "103.214.23.41"
vps_count = 0

# Tags
tags = {
  Environment = "staging"
  ManagedBy   = "terraform"
}
```

### 2.2 通过 GitHub Actions 部署 DNS

**Workflow**: `.github/workflows/terraform.yml`

触发方式:
```bash
# 推送 terraform 变更到 main
git push origin brn-004-02:main

# 或手动触发
# GitHub → Actions → Terraform Infrastructure → Run workflow
```

**预期结果**:
- ✅ DNS 记录创建: x-staging.truealpha.club → 103.214.23.41
- ✅ API 记录: api-x-staging.truealpha.club → 103.214.23.41

---

## 📋 阶段 3: 应用部署 (GitHub Actions)

### 3.1 配置 Infisical CLI (在 VPS 上)

```bash
# 在 VPS 上
curl -1sLf 'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.deb.sh' | sudo -E bash
sudo apt-get update && sudo apt-get install -y infisical

# 登录
infisical login
```

### 3.2 手动首次部署 (验证流程)

```bash
# 在 VPS 上
cd /opt/truealpha
git clone https://github.com/wangzitian0/infra.git
cd infra

# 导出 secrets
./scripts/deploy/export-secrets.sh staging

# 部署
./scripts/deploy/deploy.sh staging
```

**预期结果**:
- ✅ 所有服务启动 (backend, neo4j, postgres, redis, celery, flower, traefik)
- ✅ 健康检查通过
- ✅ https://x-staging.truealpha.club 可访问

### 3.3 配置 GitHub Actions 自动部署

**Workflow**: `.github/workflows/deploy.yml`

触发条件:
- Push to `main` branch (自动)
- Workflow dispatch (手动)

**部署流程**:
1. GitHub Actions 连接 VPS (SSH)
2. Pull 最新代码
3. 从 Infisical 导出环境变量
4. 运行 `./scripts/deploy/deploy.sh staging`
5. 验证健康检查

---

## 📋 阶段 4: 验证与监控

### 4.1 功能验证
- [ ] DNS 解析: `dig x-staging.truealpha.club`
- [ ] SSL 证书: `curl -I https://x-staging.truealpha.club`
- [ ] GraphQL API: `curl https://api-x-staging.truealpha.club/graphql`
- [ ] Neo4j: 连接测试
- [ ] PostgreSQL: 连接测试
- [ ] Redis: 连接测试
- [ ] Celery: 查看 Flower UI

### 4.2 部署 SigNoz (可选，建议第二阶段)

```bash
# 在 VPS 上
cd /opt/signoz
git clone https://github.com/SigNoz/signoz.git
cd signoz/deploy
docker compose -f docker/clickhouse-setup/docker-compose.yaml up -d
```

---

## 📋 阶段 5: PR 预览环境测试

### 5.1 创建测试 PR

1. 在 PEG-scaner 创建 PR #1
2. GitHub Actions 自动触发 `pr-preview.yml`
3. 自动创建 DNS: x-test-1.truealpha.club
4. 自动部署应用
5. PR 评论中显示预览链接

### 5.2 验证 PR 预览

- [ ] x-test-1.truealpha.club 可访问
- [ ] 独立的数据库实例
- [ ] PR 关闭后自动清理

---

## 🎯 成功标准

### 最小可行产品 (MVP)
- ✅ staging 环境完全可用
- ✅ GitHub Actions 自动部署成功
- ✅ 所有服务健康运行
- ✅ https://x-staging.truealpha.club 可访问

### 完整流程
- ✅ 代码 push → 自动部署 → 验证通过
- ✅ PR 创建 → 预览环境 → 自动清理
- ✅ Secrets 从 Infisical 自动同步
- ✅ 健康检查和回滚机制

---

## 📝 执行顺序

### Week 1: 基础设施
**Day 1-2**: VPS 准备
- [ ] 安装 Docker & Dokploy
- [ ] 配置 Infisical
- [ ] 配置 GitHub Secrets

**Day 3**: Terraform DNS
- [ ] 推送分支到 main
- [ ] 手动运行 Terraform (或通过 Actions)
- [ ] 验证 DNS 记录

### Week 2: 应用部署
**Day 4-5**: 手动部署验证
- [ ] VPS 上手动运行部署脚本
- [ ] 调试所有服务
- [ ] 确保健康检查通过

**Day 6-7**: GitHub Actions
- [ ] 配置自动部署 workflow
- [ ] 测试 push-to-deploy 流程
- [ ] 验证完整的 CI/CD

### Week 3: PR 预览与监控
**Day 8-9**: PR 预览环境
- [ ] 测试 PR 预览 workflow
- [ ] 验证自动创建/清理

**Day 10**: 监控与优化
- [ ] 部署 SigNoz
- [ ] 配置告警
- [ ] 文档更新

---

## 🚧 潜在问题与解决方案

### 问题 1: Infisical 配置复杂
**解决**: 使用 Infisical Cloud (快速)，避免自托管

### 问题 2: GitHub Actions SSH 连接失败
**解决**: 
- 确保 SSH 私钥格式正确 (PEM)
- 测试 known_hosts
- 使用 `appleboy/ssh-action`

### 问题 3: Docker Compose 服务启动失败
**解决**:
- 逐个服务启动调试
- 检查日志: `docker compose logs -f <service>`
- 验证环境变量

### 问题 4: DNS 解析延迟
**解决**:
- Cloudflare Proxied 模式有缓存
- 等待 1-5 分钟 DNS 传播

---

## 📚 相关文档

- [0.hi_zitian.md](0.hi_zitian.md) - 详细配置步骤
- [architecture.md](architecture.md) - 架构设计
- [runbooks/operations.md](runbooks/operations.md) - 运维手册
- [TODOWRITE.md](TODOWRITE.md) - 完成度追踪

---

**目标**: 2 周内完成 staging 环境端到端部署

**当前状态**: ✅ 代码完成，开始执行部署

**下一步**: 推送代码 → 准备 VPS → 配置 Secrets → 部署！
