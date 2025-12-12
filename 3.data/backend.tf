# Cloudflare R2 Backend (S3-compatible)
# State key: k3s/data.tfstate

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
