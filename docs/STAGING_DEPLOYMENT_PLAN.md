# Staging 环境全自动化部署

**核心理念**: GitOps - 一切通过 Git + GitHub Actions 自动化

**目标**: 实现 `git push` → 自动部署 staging 的完整流程

---

## 🎯 自动化部署流程

```
git push → GitHub Actions → Terraform (VPS + DNS) → Docker Compose → 健康检查 → 完成
```

**人工介入**: 仅需一次性配置 GitHub Secrets

---

## ⚙️ 一次性配置 (前置条件)

### GitHub Repository Secrets

在 `Settings → Secrets and variables → Actions` 添加：

```yaml
# VPS Access
SSH_PRIVATE_KEY: <your-ssh-private-key>  # ~/.ssh/id_rsa 内容
SSH_USER: prod
SSH_HOST: 103.214.23.41

# Cloudflare
CLOUDFLARE_API_TOKEN: <your-token>
CLOUDFLARE_ZONE_ID: <your-zone-id>

# Secrets Management (二选一)
# 方案 A: Infisical Cloud
INFISICAL_CLIENT_ID: <machine-identity-id>
INFISICAL_CLIENT_SECRET: <machine-identity-secret>
INFISICAL_PROJECT_ID: <project-id>

# 方案 B: 直接使用 GitHub Secrets (简单但不推荐生产)
# NEO4J_PASSWORD: xxx
# POSTGRES_PASSWORD: xxx
# ... (81 个环境变量)
```

**推荐方案 A** (Infisical):
1. 注册 https://app.infisical.com
2. 创建项目 "truealpha"
3. 创建环境: staging
4. 从 `secrets/.env.example` 复制并填充变量
5. 创建 Machine Identity → 获取 Client ID/Secret

---

## 🚀 完全自动化部署

### 步骤 1: 推送代码

```bash
# 合并到 main 分支
git checkout main
git merge brn-004-02
git push origin main
```

### 步骤 2: GitHub Actions 自动执行

**Workflow**: `.github/workflows/deploy-staging.yml` (新建)

```yaml
name: Deploy Staging Environment

on:
  push:
    branches: [main]
  workflow_dispatch:  # 手动触发

jobs:
  terraform:
    name: Provision Infrastructure
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3
      
      - name: Terraform Init
        working-directory: terraform/envs/staging
        run: terraform init
      
      - name: Terraform Apply (VPS + DNS)
        working-directory: terraform/envs/staging
        env:
          TF_VAR_vps_ip: ${{ secrets.SSH_HOST }}
          TF_VAR_ssh_user: ${{ secrets.SSH_USER }}
          TF_VAR_ssh_private_key: ${{ secrets.SSH_PRIVATE_KEY }}
          TF_VAR_cloudflare_api_token: ${{ secrets.CLOUDFLARE_API_TOKEN }}
          TF_VAR_cloudflare_zone_id: ${{ secrets.CLOUDFLARE_ZONE_ID }}
          TF_VAR_enable_vps_bootstrap: true
        run: |
          terraform apply -auto-approve \
            -var="environment=staging" \
            -var="project_name=truealpha" \
            -var="domain=truealpha.club"

  deploy:
    name: Deploy Application
    needs: terraform
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Deploy to VPS
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.SSH_HOST }}
          username: ${{ secrets.SSH_USER }}
          key: ${{ secrets.SSH_PRIVATE_KEY }}
          script: |
            # 克隆/更新代码
            mkdir -p /opt/truealpha
            cd /opt/truealpha
            if [ -d "infra" ]; then
              cd infra && git pull
            else
              git clone https://github.com/wangzitian0/infra.git
              cd infra
            fi
            
            # 从 Infisical 导出环境变量
            export INFISICAL_TOKEN="${{ secrets.INFISICAL_TOKEN }}"
            ./scripts/deploy/export-secrets.sh staging > .env
            
            # 部署应用
            ./scripts/deploy/deploy.sh staging
      
      - name: Health Check
        run: |
          sleep 30  # 等待服务启动
          curl -f https://x-staging.truealpha.club/health || exit 1
          curl -f https://api-x-staging.truealpha.club/graphql || exit 1
```

### 步骤 3: 验证部署

**自动化验证** (在 GitHub Actions 中):
- ✅ Terraform 成功应用
- ✅ DNS 记录创建
- ✅ VPS Docker/Dokploy 安装完成
- ✅ 应用服务启动
- ✅ 健康检查通过

**手动验证** (可选):
```bash
# DNS
dig x-staging.truealpha.club

# SSL
curl -I https://x-staging.truealpha.club

# API
curl https://api-x-staging.truealpha.club/graphql
```

---

## 🔄 持续部署

### 自动触发场景

1. **代码更新**: `git push origin main` → 自动部署
2. **配置更新**: 修改 `compose/staging.yml` → 自动部署
3. **手动触发**: GitHub UI → Actions → Run workflow

### 回滚机制

```bash
# 在 GitHub Actions 中
git revert <commit-hash>
git push origin main
# 自动触发重新部署
```

---

## 🧪 PR 预览环境 (完全自动化)

### Workflow: `.github/workflows/pr-preview.yml`

**触发**: PR 打开/更新/关闭

**流程**:
1. PR 打开 → 自动创建 DNS (`x-test-<PR#>.truealpha.club`)
2. PR 更新 → 自动重新部署
3. PR 关闭 → 自动清理资源

**示例**:
```yaml
name: PR Preview Environment

on:
  pull_request:
    types: [opened, synchronize, closed]

jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      - if: github.event.action != 'closed'
        name: Create Preview Environment
        run: |
          # Terraform 创建 DNS: x-test-${{ github.event.number }}
          # Docker Compose 部署独立实例
          # 在 PR 评论中添加预览链接
      
      - if: github.event.action == 'closed'
        name: Cleanup Preview Environment
        run: |
          # Terraform 删除 DNS
          # Docker Compose 停止并删除容器
```

---

## 📊 自动化程度对比

### 传统手动方式
```
1. SSH 登录 VPS ❌ 手动
2. 安装 Docker   ❌ 手动
3. 配置防火墙   ❌ 手动
4. 克隆代码     ❌ 手动
5. 配置环境变量 ❌ 手动
6. 启动服务     ❌ 手动
7. 验证健康     ❌ 手动
```

### 完全自动化 (EaaS)
```
1. git push origin main          ✅ 一条命令
2. 所有步骤自动执行              ✅ GitHub Actions
3. 健康检查自动验证              ✅ 自动化
4. 失败自动回滚 (optional)       ✅ 可配置
```

---

## 🎯 实施时间线

### Day 1: 配置 GitHub Secrets (30 分钟)
- [ ] 添加 SSH 密钥
- [ ] 添加 Cloudflare Token
- [ ] 配置 Infisical (或直接用 GitHub Secrets)

### Day 2: 创建自动化 Workflow (1 小时)
- [ ] 创建 `deploy-staging.yml`
- [ ] 测试 Terraform 步骤
- [ ] 测试部署步骤

### Day 3: 首次完整部署 (2 小时)
- [ ] `git push origin main`
- [ ] 监控 GitHub Actions 执行
- [ ] 验证所有服务
- [ ] 调试问题 (如有)

### Day 4-5: PR 预览环境 (1 天)
- [ ] 创建 `pr-preview.yml`
- [ ] 测试 PR 工作流
- [ ] 验证自动清理

**总计**: 3-5 天完成完全自动化

---

## 🔐 Secrets 管理策略

### 推荐: Infisical Cloud (生产级)

**优点**:
- ✅ 集中管理所有环境
- ✅ 审计日志
- ✅ 版本控制
- ✅ 细粒度权限

**使用**:
```bash
# 在 VPS 上 (GitHub Actions 自动执行)
export INFISICAL_TOKEN="${{ secrets.INFISICAL_TOKEN }}"
infisical export --env=staging > .env
```

### 备选: GitHub Secrets (开发环境)

**优点**:
- ✅ 简单快速
- ✅ 无需额外服务

**缺点**:
- ❌ GitHub Secrets 数量限制
- ❌ 81 个变量太多

---

## ✅ 成功标准

### 自动化程度
- ✅ 0 次 SSH 登录
- ✅ 0 次手动命令执行  
- ✅ 1 条命令触发部署: `git push`

### 可重复性
- ✅ 销毁环境 → 重新部署 → 完全相同
- ✅ 多个环境 (test/staging/prod) 配置一致
- ✅ PR 预览环境自动创建/销毁

### 可观测性
- ✅ GitHub Actions 日志
- ✅ 自动健康检查
- ✅ 失败通知 (可选: Slack/Email)

---

## 🚨 注意事项

### 安全
1. **SSH 密钥**: 确保使用 GitHub Secrets，不要提交到代码
2. **API Token**: 最小权限原则
3. **环境变量**: 使用 Infisical 或 GitHub Secrets，不要硬编码

### 幂等性
1. **Terraform**: 多次 apply 不会重复创建资源  
2. **Docker Compose**: restart 策略确保服务更新
3. **Secrets**: 环境变量可以重复导出

### 监控
1. **GitHub Actions**: 查看执行日志
2. **VPS 日志**: `docker compose logs -f`
3. **健康检查**: 自动验证服务状态

---

## 📚 相关文档

- [terraform.yml](../ci/github-actions/terraform.yml) - Terraform 自动化
- [deploy.yml](../ci/github-actions/deploy.yml) - 应用部署
- [pr-preview.yml](../ci/github-actions/pr-preview.yml) - PR 预览
- [TODOWRITE.md](TODOWRITE.md) - 完成度追踪

---

## 🎊 总结

**人工操作**: 仅配置 GitHub Secrets (一次)

**自动化流程**:
```
git push 
  ↓
GitHub Actions
  ↓
Terraform (VPS + DNS)
  ↓
Docker Compose (应用部署)
  ↓
健康检查
  ↓
✅ 部署成功
```

**EaaS 核心价值**: 
- 🚀 快速: 5 分钟部署完成
- 🔄 可重复: 销毁重建完全一致
- 🛡️ 可靠: 自动化减少人为错误
- 📈 可扩展: 轻松复制到更多环境
