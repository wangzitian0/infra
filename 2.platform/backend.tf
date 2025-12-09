# Cloudflare R2 Backend (S3-compatible)
# State key: k3s/platform.tfstate
#
# Init command:
#   terraform init \
#     -backend-config="bucket=$R2_BUCKET" \
#     -backend-config="key=k3s/platform.tfstate" \
#     -backend-config="endpoints={s3=\"https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com\"}"
#
# Credentials via environment variables:
#   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, R2_BUCKET, R2_ACCOUNT_ID

terraform {
  backend "s3" {
    # Partial configuration: bucket, endpoints, key passed via CLI or tfvars
    region                      = "auto"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_path_style              = true
  }
}
