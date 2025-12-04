# Cloudflare R2 Backend (S3-compatible)
# 
# CI 和本地都通过 terraform init -backend-config 传入变量：
#   terraform init \
#     -backend-config="bucket=$R2_BUCKET" \
#     -backend-config="endpoints={s3=\"https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com\"}"
#
# 凭据通过环境变量（R2 用 S3 兼容 API，所以变量名是 AWS_*）：
#   export AWS_ACCESS_KEY_ID=...
#   export AWS_SECRET_ACCESS_KEY=...

terraform {
  backend "s3" {
    # 以下值通过 -backend-config 传入
    # bucket   = 由 R2_BUCKET 提供
    # endpoints.s3 = 由 R2_ACCOUNT_ID 构造

    key                         = "k3s/terraform.tfstate"
    region                      = "auto"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    use_path_style              = true
  }
}
