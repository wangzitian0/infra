# Cloudflare DNS and CDN Configuration

locals {
  primary_ip = length(var.vps_ips) > 0 ? var.vps_ips[0] : ""
  
  # Domain names based on environment
  # Non-prod: *.{env}.x.truealpha.club (covered by *.x.truealpha.club cert)
  # Prod: *.truealpha.club (covered by *.truealpha.club cert)
  env_base_domain = var.environment == "prod" ? var.domain : "${var.environment}.x.${var.domain}"
  api_subdomain   = var.environment == "prod" ? "api" : "api.${var.environment}.x"
}

# Main domain record (prod only)
resource "cloudflare_record" "main" {
  count   = var.environment == "prod" ? 1 : 0
  zone_id = var.zone_id
  name    = "@"
  type    = "A"
  value   = local.primary_ip
  proxied = true
  comment = "Managed by Terraform - ${var.environment}"
}

# Environment base domain (dev/test/staging)
# Creates: dev.x.truealpha.club, test.x.truealpha.club, staging.x.truealpha.club
resource "cloudflare_record" "environment" {
  count   = var.environment != "prod" ? 1 : 0
  zone_id = var.zone_id
  name    = local.env_base_domain
  type    = "A"
  value   = local.primary_ip
  proxied = true
  comment = "Managed by Terraform - ${var.environment} base"
}

# API subdomain
# Creates: api.truealpha.club (prod) or api.{env}.x.truealpha.club (non-prod)
resource "cloudflare_record" "api" {
  zone_id = var.zone_id
  name    = local.api_subdomain
  type    = "A"
  value   = local.primary_ip
  proxied = true
  comment = "Managed by Terraform - ${var.environment} API"
}

# Wildcard for PR previews (test environment only)
# Creates: *.test.x.truealpha.club (e.g., pr01.test.x.truealpha.club)
resource "cloudflare_record" "pr_wildcard" {
  count   = var.environment == "test" ? 1 : 0
  zone_id = var.zone_id
<<<<<<< HEAD
<<<<<<< HEAD
  name    = "*.test.x"
  type    = "A"
  value   = local.primary_ip
  proxied = true
  comment = "Managed by Terraform - PR preview environments (prXX.test.x.truealpha.club)"
=======
  name    = "pr*"
  type    = "A"
  value   = local.primary_ip
  proxied = true
  comment = "Managed by Terraform - PR preview environments (prXX.truealpha.club)"
>>>>>>> 649fd4b (fix(terraform): clean up and ensure SSL cert compatibility)
=======
  name    = "*.test.x"
  type    = "A"
  value   = local.primary_ip
  proxied = true
  comment = "Managed by Terraform - PR preview environments (prXX.test.x.truealpha.club)"
>>>>>>> 8f3e040 (refactor(terraform): migrate to x.truealpha.club for non-prod environments)
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
