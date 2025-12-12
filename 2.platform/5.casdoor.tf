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

      # Database configuration - use L1 PostgreSQL
      database = {
        driver       = "postgres"
        user         = "postgres"
        password     = var.vault_postgres_password
        host         = "postgresql.platform.svc.cluster.local"
        port         = 5432
        databaseName = "casdoor"
        sslMode      = "disable"
      }

      # Casdoor application config
      config = {
        appname       = "casdoor"
        httpport      = 8000
        origin        = "https://${local.casdoor_domain}"
        staticBaseUrl = "https://cdn.casbin.org"
      }

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

  depends_on = [null_resource.casdoor_database]
}

# Create Casdoor database in PostgreSQL BEFORE Casdoor starts
# Database must exist for Casdoor to initialize
resource "null_resource" "casdoor_database" {
  count = local.casdoor_enabled ? 1 : 0

  provisioner "local-exec" {
    environment = {
      KUBECONFIG = var.kubeconfig_path
    }
    command = <<-EOT
      # Create casdoor database if not exists (idempotent)
      kubectl exec -n platform postgresql-0 -- bash -c "
        PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres -tc \"SELECT 1 FROM pg_database WHERE datname = 'casdoor'\" | grep -q 1 || \
        PGPASSWORD=\$POSTGRES_PASSWORD psql -U postgres -c \"CREATE DATABASE casdoor\"
      "
    EOT
  }

  # Only re-run if Casdoor is newly enabled or password changes
  triggers = {
    casdoor_enabled = local.casdoor_enabled
    pg_password     = sha256(var.vault_postgres_password)
  }
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
