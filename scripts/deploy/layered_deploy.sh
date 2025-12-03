#!/usr/bin/env bash
# Orchestrate Terraform (Layer 2) + app deploy (Layer 3) per environment.

set -euo pipefail

ENV="${1:-}"
MODE="${2:-apply}" # plan | apply

if [[ -z "$ENV" ]]; then
  echo "Usage: $0 <staging|test|prod> [plan|apply]"
  exit 1
fi

if [[ ! "$ENV" =~ ^(staging|test|prod)$ ]]; then
  echo "Error: ENV must be staging|test|prod"
  exit 1
fi

if [[ ! "$MODE" =~ ^(plan|apply)$ ]]; then
  echo "Error: MODE must be plan|apply"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="$ROOT_DIR/terraform/envs/$ENV"

echo "🚀 Layered deploy -> ENV=$ENV MODE=$MODE"

echo "📦 Step 1/3: Terraform ($MODE)"
pushd "$TF_DIR" >/dev/null
terraform init -input=false
terraform "$MODE" -input=false
popd >/dev/null

if [[ "$MODE" == "plan" ]]; then
  echo "ℹ️ Plan complete; skipping deploy for MODE=plan"
  exit 0
fi

echo "🔑 Step 2/3: Export secrets from self-hosted Infisical"
"$ROOT_DIR/scripts/deploy/export-secrets.sh" "$ENV"

echo "🚢 Step 3/3: Deploy services (compose, no UI clicks)"
"$ROOT_DIR/scripts/deploy/deploy.sh" "$ENV"

echo "✅ Layered deploy finished: $ENV"
