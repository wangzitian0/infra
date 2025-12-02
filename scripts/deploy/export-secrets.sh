#!/bin/bash
# 从 Infisical 导出环境变量

set -e

ENV=$1

if [ -z "$ENV" ]; then
    echo "Usage: $0 <environment>"
    echo "Example: $0 dev"
    exit 1
fi

# 检查 Infisical CLI 是否安装
if ! command -v infisical &> /dev/null; then
    echo "Error: Infisical CLI not found"
    echo "Install it with: brew install infisical/tap/infisical"
    exit 1
fi

# 检查是否已登录
if ! infisical whoami &> /dev/null; then
    echo "Please login to Infisical first:"
    echo "  infisical login"
    exit 1
fi

# 导出环境变量
echo "Exporting secrets for environment: $ENV"
infisical export --env="$ENV" --format=dotenv > ".env.$ENV"

echo "✓ Secrets exported to .env.$ENV"
echo ""
echo "To use these secrets:"
echo "  docker compose -f compose/base.yml -f compose/$ENV.yml --env-file .env.$ENV up -d"
