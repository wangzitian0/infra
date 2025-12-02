# VPS Outputs

output "vps_ips" {
  description = "IP addresses of VPS instances"
  value       = module.vps[*].public_ip
}

output "vps_ids" {
  description = "IDs of VPS instances"
  value       = module.vps[*].instance_id
}

# DNS Outputs

output "dns_records" {
  description = "Created DNS records"
  value = {
    main    = module.cloudflare.main_domain
    api     = module.cloudflare.api_domain
    subdomain = module.cloudflare.environment_domain
  }
}

# Database Outputs

output "database_connection" {
  description = "Database connection details"
  value       = var.enable_managed_database ? module.database[0].connection_string : "Using containerized databases"
  sensitive   = true
}

# Environment Info

output "environment_info" {
  description = "Environment configuration summary"
  value = {
    environment = var.environment
    project     = var.project_name
    domain      = var.domain
    vps_count   = var.vps_count
  }
}
