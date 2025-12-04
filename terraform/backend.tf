# Cloudflare R2 Backend (S3-compatible)
#
# 本地和 CI 使用相同命令：
#   terraform init \
#     -backend-config="bucket=$R2_BUCKET" \
#     -backend-config="endpoints={s3=\"https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com\"}"
#
# 凭据来源：
#   - 本地：export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... R2_BUCKET=... R2_ACCOUNT_ID=...
#   - CI：GitHub Secrets

terraform {
  backend "s3" {
    # bucket 和 endpoints 通过 -backend-config 传入（本地和 CI 一致）
    key                         = "k3s/terraform.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
}
