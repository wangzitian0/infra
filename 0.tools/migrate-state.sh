#!/bin/bash
set -e

# Migration Script: Splits Monolithic State into L1 and L2
# Usage: ./scripts/migrate-state.sh
# Pre-requisites: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, R2_BUCKET, R2_ACCOUNT_ID defined.

BOLD="\033[1m"
RESET="\033[0m"

echo -e "${BOLD}Refactoring Migration: Splitting L1/L2 States${RESET}"

# 1. Initialize L1 (Root)
echo "Initializing L1 (Root)..."
cd terraform
# We need to ensure we use the correct backend config
# Assuming R2_BUCKET etc are present
terraform init -reconfigure \
  -backend-config="bucket=${R2_BUCKET}" \
  -backend-config="key=k3s/terraform.tfstate" \
  -backend-config="endpoints={s3=\"https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com\"}" \
  -backend-config="skip_credentials_validation=true" \
  -backend-config="skip_region_validation=true" \
  -backend-config="skip_requesting_account_id=true" \
  -backend-config="skip_s3_checksum=true" \
  -backend-config="use_path_style=true" \
  -backend-config="region=auto"

# 2. Initialize L2 (New)
echo "Initializing L2 (New Layer)..."
cd layer2-platform
terraform init -reconfigure \
  -backend-config="bucket=${R2_BUCKET}" \
  -backend-config="key=k3s/layer2.tfstate" \
  -backend-config="endpoints={s3=\"https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com\"}" \
  -backend-config="skip_credentials_validation=true" \
  -backend-config="skip_region_validation=true" \
  -backend-config="skip_requesting_account_id=true" \
  -backend-config="skip_s3_checksum=true" \
  -backend-config="use_path_style=true" \
  -backend-config="region=auto"

cd ..

# 3. Pull States Locally
echo "Pulling states..."
terraform state pull > l1.tfstate
cd layer2-platform
terraform state pull > l2.tfstate || echo "{}" > l2.tfstate # Create empty if not exists
cd ..

# 4. Move State Items
echo "Moving 'module.platform' from L1 to L2..."
# We use terraform state mv from file to file
# Warning: This updates the local files. We need to push them back.
terraform state mv -state=l1.tfstate -state-out=layer2-platform/l2.tfstate module.platform module.platform

# 5. Push States Back
echo "Pushing states back to Remote..."
terraform state push l1.tfstate
cd layer2-platform
terraform state push l2.tfstate
cd ..

# Cleanup
rm l1.tfstate layer2-platform/l2.tfstate
rm -rf .terraform layer2-platform/.terraform

echo -e "${BOLD}Migration Complete!${RESET}"
echo "Now you can merge the PR that removes module.platform for L1 main.tf."
