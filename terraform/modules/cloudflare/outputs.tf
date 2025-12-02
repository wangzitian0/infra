output "main_domain" {
  description = "Main domain name"
  value       = var.environment == "prod" ? var.domain : "${var.environment}.${var.domain}"
}

output "api_domain" {
  description = "API domain name"
  value       = "${local.api_subdomain}.${var.domain}"
}

output "environment_domain" {
  description = "Environment-specific domain"
  value       = var.environment == "prod" ? var.domain : "${var.environment}.${var.domain}"
}

output "dns_records" {
  description = "Created DNS records"
  value = {
    main        = var.environment == "prod" ? cloudflare_record.main[0].hostname : cloudflare_record.environment[0].hostname
    api         = cloudflare_record.api.hostname
    pr_wildcard = var.environment == "test" ? cloudflare_record.pr_wildcard[0].hostname : null
  }
}
