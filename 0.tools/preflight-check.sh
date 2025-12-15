#!/usr/bin/env bash
# Pre-flight checks for Terraform deployment
# Run before terraform apply to catch common issues early
#
# Note: terraform fmt and validate are handled by separate CI steps

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEARCH_DIRS=(
  "${SCRIPT_DIR}/../1.bootstrap"
  "${SCRIPT_DIR}/../2.platform"
  "${SCRIPT_DIR}/../3.data"
  "${SCRIPT_DIR}/../4.apps"
)

echo "=== Pre-flight Checks ==="

# ============================================================
# Check: Validate Helm Repository URLs
# ============================================================
echo ""
echo "📦 Checking Helm repository URLs..."

# Extract all repository URLs from .tf files (excluding commented lines)
HELM_URLS=$(grep -rh 'repository\s*=' "${SEARCH_DIRS[@]}" --include="*.tf" 2>/dev/null | \
  grep -v '^\s*#' | \
  grep -oE 'https?://[^"]+' | \
  sort -u || true)

if [ -z "$HELM_URLS" ]; then
  echo "   No Helm repositories found in Terraform files."
else
  FAILED=0
  for url in $HELM_URLS; do
    # Try to fetch the index.yaml (standard helm repo endpoint)
    INDEX_URL="${url%/}/index.yaml"
    if curl -sf --connect-timeout 5 --max-time 10 "$INDEX_URL" > /dev/null 2>&1; then
      echo "   ✅ $url"
    else
      echo "   ❌ $url (unreachable or invalid)"
      FAILED=1
    fi
  done
  
  if [ $FAILED -eq 1 ]; then
    echo ""
    echo "❌ Some Helm repositories are unreachable!"
    echo "   Consider using mirror URLs or disabling affected resources."
    exit 1
  fi
fi

echo ""
echo "=== Pre-flight Checks Passed ✅ ==="
