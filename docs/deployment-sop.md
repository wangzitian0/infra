# 部署标准操作流程 (SOP)

**模板说明**: 此文档定义通用部署流程，适用于所有环境 (test/staging/prod)

**环境特定配置**: 见 `docs/env.d/{env}_sop.md`

---

## 📋 部署前置条件

### GitHub Secrets 配置

在 `Settings → Secrets and variables → Actions` 添加：

```yaml
# VPS Access
SSH_PRIVATE_KEY: <your-ssh-private-key>
SSH_USER: <username>
SSH_HOST: <vps-ip>

# Cloudflare
CLOUDFLARE_API_TOKEN: <your-token>
CLOUDFLARE_ZONE_ID: <your-zone-id>

# Secrets Management
INFISICAL_CLIENT_ID: <machine-identity-id>
INFISICAL_CLIENT_SECRET: <machine-identity-secret>
INFISICAL_PROJECT_ID: <project-id>
```

### Infisical 配置

1. 注册 https://app.infisical.com
2. 创建项目 "truealpha"
3. 创建环境: `{ENV_NAME}`
4. 从 `secrets/.env.example` 复制并填充 81 个变量
5. 创建 Machine Identity → 获取凭证

---

## 🚀 自动化部署流程

### 部署触发

```bash
# 方式1: 推送代码自动触发
git push origin main

# 方式2: 手动触发 GitHub Actions
# GitHub → Actions → Deploy {ENV} → Run workflow
```

### 部署步骤

**GitHub Actions 自动执行**:

1. **基础设施配置** (Terraform)
   - VPS Bootstrap (Docker + Dokploy)
   - DNS 记录创建
   - 防火墙配置

2. **应用部署** (Docker Compose)
   - 克隆/更新代码
   - 从 Infisical 导出环境变量
   - 启动所有服务

3. **健康检查**
   - 等待服务启动 (30s)
   - 验证主域名可访问
   - 验证 API 端点

---

## ✅ 部署验证

### 自动化验证 (GitHub Actions)

- ✅ Terraform apply 成功
- ✅ DNS 记录创建
- ✅ 服务启动完成
- ✅ 健康检查通过

### 手动验证 (可选)

```bash
# DNS 解析
dig {domain}

# SSL 证书
curl -I https://{domain}

# API 健康检查
curl https://api.{domain}/graphql

# 服务状态
ssh {user}@{host}
docker compose ps
```

---

## 🔄 更新部署

### 应用更新

```bash
# 修改代码
git commit -am "feat: update feature"
git push origin main
# 自动触发重新部署
```

### 配置更新

```bash
# 修改 compose 配置
vim compose/{env}.yml
git push origin main
# 自动触发重新部署
```

### 环境变量更新

```bash
# 在 Infisical 中更新变量
# 然后手动触发部署
# GitHub → Actions → Deploy {ENV} → Run workflow
```

---

## 🛑 回滚

### 方式1: Git Revert

```bash
git revert <commit-hash>
git push origin main
# 自动触发回滚部署
```

### 方式2: 重新部署特定版本

```bash
# 在 GitHub Actions 中
# 选择特定 commit 重新部署
```

---

## 🚨 故障处理

### 部署失败

1. 查看 GitHub Actions 日志
2. 检查 Terraform 错误
3. 验证 Secrets 配置
4. 检查 VPS 可访问性

### 服务启动失败

```bash
# SSH 登录 VPS
ssh {user}@{host}

# 查看服务日志
cd /opt/truealpha/infra
docker compose -p truealpha-{env} logs -f

# 检查环境变量
docker compose -p truealpha-{env} exec backend env

# 重启服务
docker compose -p truealpha-{env} restart
```

### 健康检查失败

```bash
# 检查服务状态
docker compose -p truealpha-{env} ps

# 检查网络
docker network ls | grep truealpha

# 测试服务间连接
docker compose -p truealpha-{env} exec backend ping postgres
```

---

## 📊 监控与告警

### 日志查看

```bash
# 实时日志
docker compose -p truealpha-{env} logs -f {service}

# 最近 100 行
docker compose -p truealpha-{env} logs --tail=100 {service}
```

### 资源监控

```bash
# 容器资源使用
docker stats

# 磁盘使用
df -h
docker system df
```

---

## 🔐 安全检查清单

- [ ] Secrets 已从 Infisical/GitHub Secrets 加载，未硬编码
- [ ] SSH 密钥仅存储在 GitHub Secrets
- [ ] API Token 使用最小权限
- [ ] 防火墙仅开放必要端口 (SSH/HTTP/HTTPS)
- [ ] SSL 证书配置正确
- [ ] 敏感日志已脱敏

---

## 📝 部署检查表

### 部署前

- [ ] 代码已通过 CI 测试
- [ ] 变更已 code review
- [ ] Secrets 已配置完整
- [ ] 备份当前环境（如需要）

### 部署中

- [ ] GitHub Actions 执行无错误
- [ ] Terraform apply 成功
- [ ] 所有服务启动成功
- [ ] 健康检查通过

### 部署后

- [ ] 功能验证完成
- [ ] 性能正常
- [ ] 错误日志无异常
- [ ] 更新部署文档
- [ ] 通知团队

---

## 🔗 相关文档

- **环境特定配置**: `docs/env.d/{env}_sop.md`
- **整体进度**: `docs/PROGRESS.md`
- **环境状态**: `terraform/envs/{env}/STATUS.md`
- **技术架构**: `docs/architecture.md`
- **运维手册**: `docs/runbooks/operations.md`
