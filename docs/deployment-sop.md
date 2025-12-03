# 部署标准操作流程 (SOP)

**适用范围**: test / staging / prod  
**模型**: IRD-004 三层 (Layer 1/2/3)  
**顺序**: 先完成 staging（同时完成 Layer 1），再做 test、prod  
**平台形态**: 单台 VPS，Layer 1 只安装一次（Dokploy + Infisical + CI 入口）  
**Secrets 规则**: GitHub Secrets 仅存 Infisical Machine Identity (MI) 三元组；SSH/Cloudflare/DB/应用等全部在 Infisical（唯一密钥源）  
**环境特定配置**: 见 `docs/env.d/iac_sop.md`（全局层）与 `docs/env.d/{env}_sop.md`

---

## 📋 部署前置条件

### 三层模型（组件已定）
- **Layer 1：全局平台（单次，staging 阶段完成）**  
  - 运行时与入口: Dokploy（单实例）、Traefik（随 Dokploy）、CI 入口  
  - 密钥管理: Infisical（Machine Identity）  
  - 观测/日志基座: 预留 SigNoz（后续部署）  
  - 仅在此处安装/配置，后续 test/prod 直接复用
- **Layer 2：共享基础设施（按环境，Terraform）**  
  - Cloudflare DNS/CDN/WAF、VPS 引导、数据库/缓存/对象存储/监控组件（按模块编排）  
  - 目录: `terraform/envs/{env}`，先做 staging，再 test、prod
- **Layer 3：应用层（按环境，Dokploy/Compose）**  
  - 业务服务: API、Neo4j、PostgreSQL、Redis、Celery Worker/Beat、Flower 等  
  - 配置来源: Infisical 导出的环境变量

### Secrets 来源（简化策略）

**单一真相来源**: Infisical  
**GitHub Secrets 最小化**: 仅存访问 Infisical 的凭证（3 个）

```
GitHub Secrets (3个)         Infisical (所有密钥/凭据)
    ↓                              ↓
访问 Infisical                    实际密钥 + 凭据
INFISICAL_CLIENT_ID      →   SSH_PRIVATE_KEY
INFISICAL_CLIENT_SECRET  →   CLOUDFLARE_API_TOKEN
INFISICAL_PROJECT_ID     →   Database passwords / App keys / 81 vars
```

**设计理由**:
- ✅ Infisical 提供审计日志、版本控制、细粒度权限
- ✅ 避免在两个地方同步密钥
- ✅ GitHub Secrets 只存"钥匙的钥匙"

### GitHub Secrets 配置（仅 MI 三元组）

在 `Settings → Secrets and variables → Actions` 添加：

```yaml
# 仅存访问 Infisical 的凭证
INFISICAL_CLIENT_ID: <machine-identity-id>
INFISICAL_CLIENT_SECRET: <machine-identity-secret>
INFISICAL_PROJECT_ID: <project-id>
```

### Infisical 配置（所有实际密钥）

1. 注册 https://app.infisical.com
2. 创建项目 "truealpha"
3. 创建环境: `{ENV_NAME}` (staging, test, prod)
4. 从 `secrets/.env.example` 导入并填充 **所有 81 个变量**：

```bash
# VPS Access
SSH_PRIVATE_KEY=<your-ssh-private-key>
SSH_USER=prod
SSH_HOST=103.214.23.41

# Cloudflare
CLOUDFLARE_API_TOKEN=<your-token>
CLOUDFLARE_ZONE_ID=<your-zone-id>

# Database
NEO4J_PASSWORD=<generate>
POSTGRES_PASSWORD=<generate>
REDIS_PASSWORD=<generate>

# ... 所有其他密钥
```

5. 创建 Machine Identity → 获取 Client ID/Secret（写入 GitHub Secrets）

---

## 🚀 部署流程（按顺序执行）

### 0. Layer 1（仅一次，staging 阶段完成）
在 VPS（单台）上安装：
```bash
# 安装 Docker
curl -fsSL https://get.docker.com | sh

# 安装 Dokploy（控制面 + Traefik）
curl -sSL https://dokploy.com/install.sh | sh
```
- 在 Dokploy UI 完成基础设置（管理员账户、域名入口）。  
- 确认 Infisical 可访问（Cloud 版或自托管），生成 MI。

### 1. GitHub Secrets（仅 MI 三元组）
在仓库 Settings → Secrets and variables → Actions 填写：`INFISICAL_CLIENT_ID` / `INFISICAL_CLIENT_SECRET` / `INFISICAL_PROJECT_ID`。

### 2. Infisical（唯一密钥源，分环境）
在 https://app.infisical.com：
- 创建项目 `truealpha`，环境：staging / test / prod  
- 导入 `secrets/.env.example` 中全部变量（81 个），补充真实值  
- 将以下凭据也放入 Infisical（不要放 GitHub Secrets）：`SSH_PRIVATE_KEY`、`SSH_USER`、`SSH_HOST`、`CLOUDFLARE_API_TOKEN`、`CLOUDFLARE_ZONE_ID`
- 为每个环境创建 Machine Identity（对应 GitHub Secrets 中的 MI 三元组）

### 3. Layer 2（每个环境）

```bash
cd terraform/envs/<env>   # 先做 staging，再 test、prod
terraform init
terraform plan
terraform apply
```
- 负责 Cloudflare DNS/WAF、VPS 引导、必要的基建组件。

### 4. Layer 3（每个环境，Dokploy/Compose）

```bash
# 在 CI 或本地执行
./scripts/deploy/export-secrets.sh <env>   # 从 Infisical 拉取全部变量
./scripts/deploy/deploy.sh <env>
```
- Dokploy 作为运行时，compose 定义见 `compose/{env}.yml`（API、Neo4j、PostgreSQL、Redis、Celery、Flower 等）。

### 5. 部署验证
```bash
dig <domain>
curl -I https://<domain>
curl https://api.<domain>/graphql
```
- Dokploy UI 确认应用/容器健康；后续接入 SigNoz/PostHog 做观测。

### 6. CI/CD 触发方式
```bash
# 方式1: 推送代码自动触发
git push origin main

# 方式2: 手动触发 GitHub Actions
# GitHub → Actions → Deploy {ENV} → Run workflow
```

### CI/GitHub Actions 自动执行摘要
1. 使用 MI 三元组拉取 Infisical 全部环境变量  
2. Terraform plan/apply（Cloudflare + 基建）  
3. 渲染 Dokploy/Compose（API、DB、Cache、Worker 等）并启动  
4. 健康检查：域名、API `/graphql`

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

- [ ] Secrets 已从 Infisical 拉取（GitHub Secrets 仅含 MI 三元组），未硬编码
- [ ] SSH/Cloudflare 等凭据仅存于 Infisical
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
- **项目主文档**: `docs/project/BRN-004/` (progress/decisions/ops)
- **技术架构**: `docs/architecture.md`
- **运维手册**: `docs/runbooks/operations.md`
