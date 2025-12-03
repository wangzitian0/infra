#!/usr/bin/env bash
# Deploy self-hosted Infisical stack via docker compose (local on host).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="$ROOT_DIR/secrets/.env.infisical"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Missing $ENV_FILE. Copy secrets/.env.infisical.example and fill values."
  exit 1
fi

echo "🚀 Deploying self-hosted Infisical stack (compose/platform/infisical.yml) to secrets.truealpha.club..."
docker compose -f "$ROOT_DIR/compose/platform/infisical.yml" --env-file "$ENV_FILE" up -d

echo "✅ Infisical stack started. Edit $ENV_FILE as needed and redeploy if values change."
echo "   UI (via proxy): https://secrets.truealpha.club"
