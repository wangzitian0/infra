#!/bin/bash
# Data Import Script - Shared logic for importing existing Data layer resources into Terraform state
# Used by Digger for Data resource state synchronization
#
# Usage: ./tools/data-import.sh <namespace> [terragrunt_command]
#
# Examples:
#   ./tools/data-import.sh "data-prod" "terragrunt"
#   ./tools/data-import.sh "data-staging" "terragrunt"

set -euo pipefail

NS="${1:-}"
TG_CMD="${2:-terragrunt}"

if [ -z "$NS" ]; then
  echo "❌ Error: Namespace argument required"
  echo "Usage: $0 <namespace> [terragrunt_command]"
  exit 1
fi

echo "=== Data Resource Import Check (NS: $NS) ==="
echo "Using Terragrunt command: $TG_CMD"

# Import namespace if exists but not in state
if kubectl get ns "$NS" 2>/dev/null && ! $TG_CMD state show kubernetes_namespace.data 2>/dev/null; then
  echo "Importing kubernetes_namespace.data..."
  $TG_CMD import kubernetes_namespace.data "$NS" || true
fi

# Import helm releases if they exist but not in state
declare -A HELM_RELEASES=(
  ["helm_release.redis_operator"]="redis-operator"
  ["helm_release.clickhouse_operator"]="clickhouse-operator"
  ["helm_release.arangodb_operator"]="arangodb-operator"
)

for tf_resource in "${!HELM_RELEASES[@]}"; do
  release_name="${HELM_RELEASES[$tf_resource]}"
  if helm status "$release_name" -n "$NS" 2>/dev/null && ! $TG_CMD state show "$tf_resource" 2>/dev/null; then
    echo "Importing $tf_resource..."
    $TG_CMD import "$tf_resource" "$NS/$release_name" || true
  fi
done

# Import kubernetes_secret.arangodb_jwt if exists but not in state
if kubectl get secret arangodb-jwt -n "$NS" 2>/dev/null && ! $TG_CMD state show kubernetes_secret.arangodb_jwt 2>/dev/null; then
  echo "Importing kubernetes_secret.arangodb_jwt..."
  $TG_CMD import kubernetes_secret.arangodb_jwt "$NS/arangodb-jwt" || true
fi

echo "✅ Data import check complete"
