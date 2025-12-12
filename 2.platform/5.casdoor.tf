# Casdoor - Unified SSO Platform
# Namespace: platform
# URL: sso.{internal_domain} (e.g., sso.zitian.party)
# Database: L1 Platform PostgreSQL (vault database, separate casdoor schema)
#
# Purpose: Centralized authentication for all L2+ services
# - GitHub/Google OAuth as identity providers
# - OIDC provider for Vault, Dashboard, Kubero, etc.
#
# SETUP REQUIRED:
# 1. GitHub OAuth App already exists (reusing OAuth2-Proxy credentials)
# 2. Database will be created in same PostgreSQL as Vault

locals {
  casdoor_enabled = var.github_oauth_client_id != "" && var.github_oauth_client_secret != ""
  casdoor_domain  = "sso.${local.internal_domain}"
}

# Generate random password for Casdoor admin (stored in TF state, not in code)
# After deployment, retrieve with: terraform output casdoor_admin_password
resource "random_password" "casdoor_admin" {
  count   = local.casdoor_enabled ? 1 : 0
  length  = 20
  special = false
}

# Casdoor Helm Release
resource "helm_release" "casdoor" {
  count = local.casdoor_enabled ? 1 : 0

  name             = "casdoor"
  repository       = "oci://registry-1.docker.io/casbin"
  chart            = "casdoor-helm-charts"
  version          = "v1.702.0"
  namespace        = data.kubernetes_namespace.platform.metadata[0].name
  create_namespace = false
  timeout          = 300
  wait             = true

  values = [
    yamlencode({
      replicaCount = 1

      image = {
        repository = "casbin"
        name       = "casdoor"
        tag        = "v1.702.0"
        pullPolicy = "IfNotPresent"
      }

      # Casdoor app.conf - ALL config must be in this string (INI format)
      # The helm chart ignores separate "database" map, only uses "config" string
      config = <<-EOT
appname = casdoor
httpport = 8000
origin = https://${local.casdoor_domain}
staticBaseUrl = https://cdn.casbin.org

# Database configuration
driverName = postgres
dataSourceName = user=postgres password=${var.vault_postgres_password} host=postgresql.platform.svc.cluster.local port=5432 dbname=casdoor sslmode=disable
dbName = casdoor
EOT

      # Initial data configuration (IaC pattern - replaces manual setup)
      # This JSON is mounted as /conf/init_data.json and loaded on first startup
      initData = jsonencode({
        organizations = [
          {
            owner         = "admin"
            name          = "built-in"
            createdTime   = "2025-01-01T00:00:00Z"
            displayName   = "Built-in Organization"
            websiteUrl    = "https://${local.casdoor_domain}"
            favicon       = "https://cdn.casbin.org/img/casbin.svg"
            passwordType  = "plain"
            defaultAvatar = "https://cdn.casbin.org/img/casbin.svg"
          }
        ]
        users = [
          {
            owner         = "built-in"
            name          = "admin"
            createdTime   = "2025-01-01T00:00:00Z"
            displayName   = "Admin"
            type          = "normal-user"
            password      = random_password.casdoor_admin[0].result
            passwordType  = "plain"
            isAdmin       = true
            isGlobalAdmin = true
          }
        ]
        applications = [
          {
            owner          = "admin"
            name           = "app-built-in"
            createdTime    = "2025-01-01T00:00:00Z"
            displayName    = "Built-in Application"
            organization   = "built-in"
            clientId       = "auto-generated"
            clientSecret   = "auto-generated"
            redirectUris   = ["https://${local.casdoor_domain}/callback"]
            enablePassword = true
          }
        ]
      })

      service = {
        type = "ClusterIP"
        port = 8000
      }

      ingress = {
        enabled   = true
        className = "traefik"
        annotations = {
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
        }
        hosts = [
          {
            host = local.casdoor_domain
            paths = [
              {
                path     = "/"
                pathType = "Prefix"
              }
            ]
          }
        ]
        tls = [
          {
            secretName = "casdoor-tls"
            hosts      = [local.casdoor_domain]
          }
        ]
      }

      resources = {
        limits = {
          cpu    = "500m"
          memory = "512Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
    })
  ]

  # NOTE: Casdoor database is created by L1 (1.bootstrap/5.platform_pg.tf)
  # because Atlantis pod doesn't have kubectl. L1 CI runner does.
  depends_on = [data.kubernetes_namespace.platform]
}

# DNS Record for Casdoor
resource "cloudflare_record" "casdoor" {
  count = local.casdoor_enabled && var.vps_host != "" ? 1 : 0

  zone_id = data.cloudflare_zone.internal.id
  name    = "sso"
  content = var.vps_host
  type    = "A"
  ttl     = 300
  proxied = false
}

# Output
output "casdoor_url" {
  value       = local.casdoor_enabled ? "https://${local.casdoor_domain}" : "Casdoor not enabled (missing OAuth credentials)"
  description = "Casdoor SSO URL"
}

output "casdoor_admin_password" {
  value       = local.casdoor_enabled ? random_password.casdoor_admin[0].result : null
  description = "Casdoor admin password (retrieve with: terraform output -raw casdoor_admin_password)"
  sensitive   = true
}
