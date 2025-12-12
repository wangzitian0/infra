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
  # Use nonsensitive() to avoid tainting downstream outputs as sensitive.
  casdoor_enabled = nonsensitive(var.github_oauth_client_id) != "" && nonsensitive(var.github_oauth_client_secret) != ""
  casdoor_domain  = "sso.${local.internal_domain}"
}

# Generate random password for Casdoor admin (stored in TF state, not in code)
# After deployment, retrieve with: terraform output casdoor_admin_password
resource "random_password" "casdoor_admin" {
  count   = local.casdoor_enabled ? 1 : 0
  length  = 20
  special = false
}

# ConfigMap for Casdoor init_data.json
# This file is loaded on first startup to initialize organization, user, and application
resource "kubernetes_config_map" "casdoor_init_data" {
  count = local.casdoor_enabled ? 1 : 0

  metadata {
    name      = "casdoor-init-data"
    namespace = data.kubernetes_namespace.platform.metadata[0].name
  }

  data = {
    "init_data.json" = jsonencode({
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
          accountItems  = []
          tags          = []
          languages     = []
          mfaItems      = []
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
          clientId       = "casdoor-builtin-app"
          clientSecret   = random_password.casdoor_admin[0].result
          redirectUris   = ["https://${local.casdoor_domain}/callback"]
          enablePassword = true
          providers      = []
          signinMethods  = []
          signupItems    = []
          grantTypes     = []
          tags           = []
        }
      ]
    })
  }
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
  timeout          = 120
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

# Path to init_data.json (mounted via extraVolumes from ConfigMap)
initDataFile = /init-data/init_data.json
EOT

      # Mount init_data.json ConfigMap via extraVolumes (initData field is NOT supported by Helm chart)
      # This properly mounts the JSON file that Casdoor reads on first startup
      # Note: We mount to /init-data/ because /conf is managed by the chart's projected volume
      extraVolumes = [
        {
          name = "init-data"
          configMap = {
            name = kubernetes_config_map.casdoor_init_data[0].metadata[0].name
          }
        }
      ]

      extraVolumeMounts = [
        {
          name      = "init-data"
          mountPath = "/init-data"
          readOnly  = true
        }
      ]

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

      # Startup probe (Casdoor community recommendation for slow-starting apps)
      # Allows 120s for DB connection and schema initialization before liveness kicks in
      startupProbe = {
        httpGet = {
          path = "/"
          port = "http"
        }
        failureThreshold = 12
        periodSeconds    = 10
        # 12 * 10 = 120s max startup time
      }

      # Liveness probe (only starts after startupProbe succeeds)
      livenessProbe = {
        httpGet = {
          path = "/"
          port = "http"
        }
        failureThreshold = 3
        periodSeconds    = 10
      }

      # Readiness probe
      readinessProbe = {
        httpGet = {
          path = "/"
          port = "http"
        }
        failureThreshold = 3
        periodSeconds    = 10
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
