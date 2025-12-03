# Cloudflare DNS and CDN Configuration

locals {
  primary_ip = length(var.vps_ips) > 0 ? var.vps_ips[0] : ""
  
  # Domain names based on environment
  # Non-prod: x-{env}.truealpha.club (Cloudflare free tier compatible)
  # Prod: truealpha.club, api.truealpha.club
  # Flat structure with hyphens only (SSL cert: *.truealpha.club)
  env_subdomain = var.environment == "prod" ? "@" : "x-${var.environment}"
  api_subdomain = var.environment == "prod" ? "api" : "api-x-${var.environment}"
}

# Global platform records (managed once via staging to avoid duplication)
resource "cloudflare_record" "platform_cloud" {
  count   = var.environment == "staging" ? 1 : 0
  zone_id = var.zone_id
  name    = "cloud"
  type    = "A"
  content = local.primary_ip
  proxied = true
  comment = "Dokploy control plane"
}

resource "cloudflare_record" "platform_secrets" {
  count   = var.environment == "staging" ? 1 : 0
  zone_id = var.zone_id
  name    = "secrets"
  type    = "A"
  content = local.primary_ip
  proxied = true
  comment = "Self-hosted Infisical"
}

# Main domain record (prod only)
resource "cloudflare_record" "main" {
  count   = var.environment == "prod" ? 1 : 0
  zone_id = var.zone_id
  name    = "@"
  type    = "A"
  content = local.primary_ip
  proxied = true
  comment = "Managed by Terraform - ${var.environment}"
}

# Environment subdomain (test/staging)
# Creates: x-test.truealpha.club, x-staging.truealpha.club
resource "cloudflare_record" "environment" {
  count   = var.environment != "prod" ? 1 : 0
  zone_id = var.zone_id
  name    = local.env_subdomain
  type    = "A"
  content = local.primary_ip
  proxied = true
  comment = "Managed by Terraform - ${var.environment}"
}

# API subdomain
# Creates: api.truealpha.club (prod) or api-x-{env}.truealpha.club (non-prod)
resource "cloudflare_record" "api" {
  zone_id = var.zone_id
  name    = local.api_subdomain
  type    = "A"
  content = local.primary_ip
  proxied = true
  comment = "Managed by Terraform - ${var.environment} API"
}

# Wildcard for PR previews (test environment only)
# Creates: x-test-*.truealpha.club (e.g., x-test-1.truealpha.club, x-test-21.truealpha.club)
resource "cloudflare_record" "pr_wildcard" {
  count   = var.environment == "test" ? 1 : 0
  zone_id = var.zone_id
  name    = "x-test-*"
  type    = "A"
  content = local.primary_ip
  proxied = true
  comment = "Managed by Terraform - PR preview (x-test-N.truealpha.club)"
}

# CDN Cache Rules
# CDN Cache Rules (Temporarily disabled due to API Token limitations)
# resource "cloudflare_page_rule" "cache_static" {
#   zone_id = var.zone_id
#   target  = "*.${var.domain}/static/*"
#   priority = 1
# 
#   actions {
#     cache_level         = "cache_everything"
#     edge_cache_ttl      = 86400
#     browser_cache_ttl   = 3600
#   }
# }

# API Cache Rules (Temporarily disabled)
# resource "cloudflare_page_rule" "api_no_cache" {
#   zone_id = var.zone_id
#   target  = "${local.api_subdomain}.${var.domain}/graphql"
#   priority = 2
# 
#   actions {
#     cache_level = "bypass"
#   }
# }

# WAF Rules (Temporarily disabled due to syntax error)
# resource "cloudflare_firewall_rule" "rate_limit_api" {
#   count       = var.enable_rate_limiting ? 1 : 0
#   zone_id     = var.zone_id
#   description = "Rate limit API endpoints - ${var.environment}"
#   filter_id   = cloudflare_filter.rate_limit_api[0].id
#   action      = "challenge"
# }

# resource "cloudflare_filter" "rate_limit_api" {
#   count       = var.enable_rate_limiting ? 1 : 0
#   zone_id     = var.zone_id
#   description = "Rate limit API filter"
#   expression  = "(http.request.uri.path contains \"/graphql\" and rate.requests.10s > 100)"
# }

# Block common attack patterns
# resource "cloudflare_firewall_rule" "block_bad_bots" {
#   count       = var.enable_waf ? 1 : 0
#   zone_id     = var.zone_id
#   description = "Block known bad bots - ${var.environment}"
#   filter_id   = cloudflare_filter.bad_bots[0].id
#   action      = "block"
# }

# resource "cloudflare_filter" "bad_bots" {
#   count       = var.enable_waf ? 1 : 0
#   zone_id     = var.zone_id
#   description = "Bad bots filter"
#   expression  = "(cf.client.bot)"
# }

# SSL/TLS Settings
resource "cloudflare_zone_settings_override" "ssl_settings" {
  zone_id = var.zone_id

  settings {
    ssl                      = "strict"
    always_use_https         = "on"
    min_tls_version          = "1.2"
    opportunistic_encryption = "on"
    tls_1_3                  = "on"
    automatic_https_rewrites = "on"
    security_level           = var.environment == "prod" ? "high" : "medium"
  }
}
