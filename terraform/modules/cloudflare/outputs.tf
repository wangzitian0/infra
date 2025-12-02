# Outputs

output "main_domain" {
  description = "Main domain endpoint"
  value       = var.environment == "prod" ? var.domain : "${var.environment}.x.${var.domain}"
}

output "api_domain" {
  description = "API domain endpoint"
  value       = var.environment == "prod" ? "api.${var.domain}" : "api.${var.environment}.x.${var.domain}"
}

output "environment_domain" {
  description = "Environment-specific domain"
  value       = var.environment == "prod" ? var.domain : "${var.environment}.x.${var.domain}"
}

output "dns_records" {
  description = "Created DNS records"
  value = {
    main       = var.environment == "prod" ? var.domain : "${var.environment}.x.${var.domain}"
    api        = var.environment == "prod" ? "api.${var.domain}" : "api.${var.environment}.x.${var.domain}"
    subdomain  = var.environment == "prod" ? var.domain : "${var.environment}.x.${var.domain}"
  }
}
