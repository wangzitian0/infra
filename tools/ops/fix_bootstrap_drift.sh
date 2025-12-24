#!/bin/bash
set -e

echo "⚠️  This script fixes the Bootstrap Layer State Drift."
echo "    It imports existing resources into Terraform state so 'apply' can succeed."
echo "    Run this from the project root with valid AWS credentials for R2."

if [ ! -d "bootstrap" ]; then
    echo "❌ Error: 'bootstrap' directory not found. Please run from project root."
    exit 1
fi

cd bootstrap

echo "Initializing Terraform..."
# Ensure terraform is initialized (assuming backend is configured or passed via env/args if run manually)
# If run via tools/ci_load_secrets wrapper, it handles init. 
# Here we assume user has run init or will run this in an initialized env.
if [ ! -d ".terraform" ]; then
    echo "⚠️  .terraform directory not found. Please run 'terraform init' first."
    exit 1
fi

# 1. Namespaces
echo ">>> Importing Namespaces..."
terraform import kubernetes_namespace.bootstrap bootstrap || echo "   (Import failed or already exists, continuing...)"
terraform import kubernetes_namespace.cert_manager cert-manager || echo "   (Import failed or already exists, continuing...)"
terraform import kubernetes_namespace.platform platform || echo "   (Import failed or already exists, continuing...)"

# 2. Storage
echo ">>> Importing Storage..."
terraform import kubernetes_storage_class.local_path_retain local-path-retain || echo "   (Import failed or already exists, continuing...)"
terraform import kubernetes_config_map_v1.local_path_config kube-system/local-path-config || echo "   (Import failed or already exists, continuing...)"

# 3. Helm Releases (Critical: CertManager & CNPG)
echo ">>> Importing Helm Releases..."
terraform import helm_release.cnpg_operator cnpg-system/cnpg || echo "   (Import failed or already exists, continuing...)"
terraform import helm_release.cert_manager cert-manager/cert-manager || echo "   (Import failed or already exists, continuing...)"

# 4. Secrets (Try import, might fail if not exists which is fine)
echo ">>> Importing Secrets..."
terraform import kubernetes_secret.cloudflare_api_token cert-manager/cloudflare-api-token-secret || echo "   (Import failed or already exists, continuing...)"
terraform import kubernetes_secret.platform_pg_superuser platform/platform-pg-superuser || echo "   (Import failed or already exists, continuing...)"

echo ""
echo "✅ Import sequence complete."
echo "👉 Now run: 'terraform plan' to verify clean state."
echo "👉 Then run: 'terraform apply' to deploy Digger and config updates."
echo "🗑️  Don't forget to manually remove Atlantis if it's still running:"
echo "    helm uninstall atlantis -n bootstrap"
