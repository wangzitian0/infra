#!/bin/bash
# 部署应用到指定环境

set -e

ENV=${1:-dev}
VERSION=${2:-latest}

echo "🚀 Deploying to environment: $ENV"
echo "📦 Version: $VERSION"

# 检查环境是否有效
if [[ ! "$ENV" =~ ^(dev|test|staging|prod)$ ]]; then
    echo "Error: Invalid environment. Must be one of: dev, test, staging, prod"
    exit 1
fi

# 生产环境需要额外确认
if [ "$ENV" = "prod" ]; then
    read -p "⚠️  Are you sure you want to deploy to PRODUCTION? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Deployment cancelled"
        exit 0
    fi
fi

# 1. 导出环境变量 (如果没有 .env 文件)
if [ ! -f ".env.$ENV" ]; then
    echo "📥 Exporting secrets from Infisical..."
    ./scripts/deploy/export-secrets.sh "$ENV"
fi

# 2. 验证 Docker Compose 配置
echo "✓ Validating Docker Compose configuration..."
docker compose \
    -f compose/base.yml \
    -f compose/$ENV.yml \
    --env-file .env.$ENV \
    config > /dev/null

# 3. 拉取最新镜像
echo "📥 Pulling latest images..."
export VERSION=$VERSION
docker compose \
    -f compose/base.yml \
    -f compose/$ENV.yml \
    --env-file .env.$ENV \
    pull

# 4. 停止旧容器（保留数据卷）
echo "🛑 Stopping old containers..."
docker compose \
    -f compose/base.yml \
    -f compose/$ENV.yml \
    --env-file .env.$ENV \
    -p truealpha-$ENV \
    down --remove-orphans

# 5. 启动新容器
echo "🚀 Starting new containers..."
docker compose \
    -f compose/base.yml \
    -f compose/$ENV.yml \
    --env-file .env.$ENV \
    -p truealpha-$ENV \
    up -d

# 6. 等待健康检查
echo "⏳ Waiting for health checks..."
sleep 10

# 7. 显示状态
echo "📊 Container status:"
docker compose -p truealpha-$ENV ps

echo ""
echo "✅ Deployment to $ENV completed successfully!"
echo ""
echo "To view logs:"
echo "  docker compose -p truealpha-$ENV logs -f [service-name]"
