# 运维手册 - 常见操作指南

## 部署相关

### 部署到指定环境

```bash
# 部署到 dev
./scripts/deploy/deploy.sh dev

# 部署到 staging（指定版本）
./scripts/deploy/deploy.sh staging v1.2.3

# 部署到 prod
./scripts/deploy/deploy.sh prod v1.2.3
```

### 查看服务状态

```bash
# 查看所有服务状态
docker compose -p truealpha-{env} ps

# 查看特定服务日志
docker compose -p truealpha-{env} logs -f backend

# 实时查看所有日志
docker compose -p truealpha-{env} logs -f
```

### 重启服务

```bash
# 重启单个服务
docker compose -p truealpha-{env} restart backend

# 重启所有服务
docker compose -p truealpha-{env} restart
```

## 数据库操作

### Neo4j 备份与恢复

```bash
# 备份
docker compose -p truealpha-prod exec neo4j \
  neo4j-admin database dump --to-path=/backup neo4j

# 恢复
docker compose -p truealpha-prod exec neo4j \
  neo4j-admin database load --from-path=/backup neo4j
```

### PostgreSQL 备份与恢复

```bash
# 备份
docker compose -p truealpha-prod exec postgres \
  pg_dump -U truealpha truealpha > backup_$(date +%Y%m%d).sql

# 恢复
cat backup_20231201.sql | \
  docker compose -p truealpha-prod exec -T postgres \
  psql -U truealpha truealpha
```

### 数据库连接

```bash
# Neo4j (Cypher Shell)
docker compose -p truealpha-{env} exec neo4j \
  cypher-shell -u neo4j -p password

# PostgreSQL
docker compose -p truealpha-{env} exec postgres \
  psql -U truealpha truealpha
```

## Terraform 操作

### 查看计划

```bash
cd terraform/envs/{env}
terraform init
terraform plan -var-file=terraform.tfvars
```

### 应用变更

```bash
# 通过 Atlantis（推荐）
# 在 PR 中评论：atlantis plan
# 审查后评论：atlantis apply

# 手动应用（仅用于紧急情况）
terraform apply -var-file=terraform.tfvars
```

### 查看当前资源

```bash
terraform show
terraform output
```

## 密钥管理

### 从 Infisical 导出

```bash
# 导出到文件
./scripts/deploy/export-secrets.sh dev

# 查看配置（不保存）
infisical export --env=prod --format=dotenv
```

### 更新密钥

```bash
# 通过 Infisical CLI
infisical secrets set API_KEY "new_value" --env=prod

# 或通过 Web UI
# https://app.infisical.com
```

## 监控与调试

### SigNoz 查询

访问 SigNoz UI: `http://signoz.{domain}:3301`

```sql
-- 查询最近错误
SELECT * FROM traces
WHERE status = 'error'
ORDER BY timestamp DESC
LIMIT 100
```

### PostHog 事件查询

访问 PostHog UI: `http://posthog.{domain}:8000`

### Flower (Celery 监控)

访问 Flower UI: `http://flower.{domain}:5555`

```bash
# 查看 worker 状态
docker compose -p truealpha-{env} exec celery-worker \
  celery -A app.celery inspect active

# 清空队列
docker compose -p truealpha-{env} exec celery-worker \
  celery -A app.celery purge
```

## 故障排查

### 服务无法启动

```bash
# 1. 检查配置
docker compose -f compose/base.yml -f compose/{env}.yml config

# 2. 查看详细日志
docker compose -p truealpha-{env} logs --tail=100 backend

# 3. 检查健康状态
docker compose -p truealpha-{env} ps
```

### 数据库连接失败

```bash
# 检查数据库是否启动
docker compose -p truealpha-{env} ps neo4j postgres

# 测试连接
docker compose -p truealpha-{env} exec backend \
  python -c "from app.db import test_connection; test_connection()"
```

### 内存/磁盘不足

```bash
# 清理未使用的 Docker 资源
docker system prune -a

# 清理特定项目的卷
docker volume ls | grep truealpha-{env} | awk '{print $2}' | xargs docker volume rm
```

## 扩容操作

### 增加 Celery Worker

```bash
# 临时增加 worker
docker compose -p truealpha-prod up -d --scale celery-worker=5

# 永久修改（编辑 compose/prod.yml）
# deploy:
#   replicas: 5
```

### 升级 VPS 规格

```bash
# 1. 修改 terraform/envs/prod/terraform.tfvars
# vps_size = "s-4vcpu-8gb"

# 2. 通过 Atlantis 或手动应用
terraform apply

# 3. 重新部署应用
./scripts/deploy/deploy.sh prod
```

## 回滚操作

### 应用回滚

```bash
# 回滚到指定版本
./scripts/deploy/deploy.sh prod v1.2.2

# 或使用 Docker 镜像 tag
VERSION=v1.2.2 ./scripts/deploy/deploy.sh prod
```

### Terraform 回滚

```bash
# 1. 查看历史状态
terraform state list

# 2. 回滚到上一个 commit
git checkout HEAD~1 terraform/envs/prod/
terraform apply

# 3. 推送回滚
git commit -m "Rollback prod infrastructure"
git push
```

### 数据库回滚

```bash
# 从备份恢复
# 参见"数据库操作"章节
```

## 安全事件响应

### 密钥泄露

```bash
# 1. 立即轮换密钥
infisical secrets set API_KEY "new_secure_key" --env=prod

# 2. 重新部署应用
./scripts/deploy/export-secrets.sh prod
./scripts/deploy/deploy.sh prod

# 3. 检查访问日志
docker compose -p truealpha-prod logs backend | grep "API_KEY"
```

### 可疑流量

```bash
# 1. 查看 Cloudflare 防火墙日志
# 通过 Cloudflare Dashboard

# 2. 临时封禁 IP（通过 Terraform）
# 修改 terraform/modules/cloudflare/main.tf
# 添加 IP 黑名单规则

# 3. 重启受影响的服务
docker compose -p truealpha-prod restart backend
```

## 定期维护

### 每日检查

```bash
# 检查服务状态
docker compose -p truealpha-prod ps

# 检查磁盘使用
df -h

# 检查日志中的错误
docker compose -p truealpha-prod logs --since 24h | grep ERROR
```

### 每周任务

- 检查 SigNoz 告警
- 审查 PostHog 异常事件
- 验证备份完整性
- 检查 SSL 证书有效期

### 每月任务

- 更新依赖（Docker 镜像）
- 审查访问日志
- 性能优化
- 成本分析

## 联系方式

- **On-call**: [手机/Slack]
- **团队频道**: [Slack/Discord]
- **文档**: [Backstage/Wiki]
