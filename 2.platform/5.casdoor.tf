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
  casdoor_enabled     = nonsensitive(var.github_oauth_client_id) != "" && nonsensitive(var.github_oauth_client_secret) != ""
  casdoor_domain      = "sso.${local.internal_domain}"
  portal_gate_enabled = local.casdoor_enabled && var.enable_portal_sso_gate

  # OIDC Client Secrets: prefer manual values from 1Password, fallback to auto-generated
  # This ensures disaster recovery consistency when Terraform state is lost
  casdoor_portal_gate_client_secret = var.casdoor_portal_client_secret != "" ? var.casdoor_portal_client_secret : (local.portal_gate_enabled ? random_password.portal_gate_client_secret[0].result : "")
  vault_oidc_client_secret          = var.casdoor_vault_oidc_client_secret != "" ? var.casdoor_vault_oidc_client_secret : (local.portal_gate_enabled ? random_password.vault_oidc_client_secret[0].result : "")
  dashboard_oidc_client_secret      = var.casdoor_dashboard_oidc_client_secret != "" ? var.casdoor_dashboard_oidc_client_secret : (local.portal_gate_enabled ? random_password.dashboard_oidc_client_secret[0].result : "")
  kubero_oidc_client_secret         = var.casdoor_kubero_oidc_client_secret != "" ? var.casdoor_kubero_oidc_client_secret : (local.portal_gate_enabled ? random_password.kubero_oidc_client_secret[0].result : "")

  # Common OAuth provider and signin methods for Casdoor applications
  casdoor_oauth_providers = [
    {
      name      = "provider_github"
      canSignUp = true
      canSignIn = true
      canUnlink = false
      prompted  = false
      alertType = ""
      rule      = "None"
      provider  = null
    }
  ]
  casdoor_signin_methods = [
    {
      name        = "OAuth"
      displayName = "OAuth"
      rule        = "All"
    }
  ]
}

resource "random_password" "portal_gate_client_secret" {
  count   = local.portal_gate_enabled && var.casdoor_portal_client_secret == "" ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "vault_oidc_client_secret" {
  count   = local.portal_gate_enabled && var.casdoor_vault_oidc_client_secret == "" ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "dashboard_oidc_client_secret" {
  count   = local.portal_gate_enabled && var.casdoor_dashboard_oidc_client_secret == "" ? 1 : 0
  length  = 32
  special = false
}

resource "random_password" "kubero_oidc_client_secret" {
  count   = local.portal_gate_enabled && var.casdoor_kubero_oidc_client_secret == "" ? 1 : 0
  length  = 32
  special = false
}

# Casdoor admin password now comes from 1Password via var.casdoor_admin_password
# (GitHub Secret CASDOOR_ADMIN_PASSWORD → TF_VAR_casdoor_admin_password)

# ConfigMap for Casdoor init_data.json
# This file is loaded on first startup to initialize organization, user, and application
#
# DISASTER RECOVERY STRATEGY:
# - init_data.json is ONLY read when Casdoor database is empty (first boot)
# - For ongoing consistency, OIDC client secrets should be stored in 1Password
# - If Terraform state is lost but Casdoor DB persists: export secrets from Casdoor,
#   set TF_VAR_casdoor_*_client_secret, then re-apply
# - If both state and DB are lost: secrets auto-regenerate from init_data on first boot
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
      providers = [
        {
          owner        = "built-in"
          name         = "provider_github"
          createdTime  = "2025-01-01T00:00:00Z"
          displayName  = "GitHub"
          category     = "OAuth"
          type         = "GitHub"
          clientId     = var.github_oauth_client_id
          clientSecret = var.github_oauth_client_secret
          host         = ""
          port         = 0
        }
      ]
      users = [
        {
          owner         = "built-in"
          name          = "admin"
          createdTime   = "2025-01-01T00:00:00Z"
          displayName   = "Admin"
          type          = "normal-user"
          password      = var.casdoor_admin_password
          passwordType  = "plain"
          isAdmin       = true
          isGlobalAdmin = true
        }
      ]
      applications = concat(
        [
          {
            owner          = "admin"
            name           = "app-built-in"
            createdTime    = "2025-01-01T00:00:00Z"
            displayName    = "Built-in Application"
            organization   = "built-in"
            clientId       = "casdoor-builtin-app"
            clientSecret   = var.casdoor_admin_password
            redirectUris   = ["https://${local.casdoor_domain}/callback"]
            enablePassword = true
            providers      = []
            signinMethods  = []
            signupItems    = []
            grantTypes     = []
            tags           = []
          }
        ],
        local.portal_gate_enabled ? [
          {
            owner          = "admin"
            name           = "portal-gate"
            createdTime    = "2025-01-01T00:00:00Z"
            displayName    = "Portal SSO Gate"
            organization   = "built-in"
            clientId       = var.casdoor_portal_client_id
            clientSecret   = local.casdoor_portal_gate_client_secret
            redirectUris   = ["https://auth.${local.internal_domain}/oauth2/callback"]
            enablePassword = false
            providers      = local.casdoor_oauth_providers
            signinMethods  = local.casdoor_signin_methods
            signupItems    = []
            grantTypes     = ["authorization_code", "refresh_token"]
            tags           = []
          },
          {
            owner          = "admin"
            name           = "vault-oidc"
            createdTime    = "2025-01-01T00:00:00Z"
            displayName    = "Vault OIDC"
            organization   = "built-in"
            clientId       = "vault-oidc"
            clientSecret   = local.vault_oidc_client_secret
            redirectUris   = ["https://secrets.${local.internal_domain}/ui/vault/auth/oidc/oidc/callback"]
            enablePassword = false
            providers      = local.casdoor_oauth_providers
            signinMethods  = local.casdoor_signin_methods
            signupItems    = []
            grantTypes     = ["authorization_code", "refresh_token"]
            tags           = []
          },
          {
            owner          = "admin"
            name           = "dashboard-oidc"
            createdTime    = "2025-01-01T00:00:00Z"
            displayName    = "Dashboard OIDC"
            organization   = "built-in"
            clientId       = "dashboard-oidc"
            clientSecret   = local.dashboard_oidc_client_secret
            redirectUris   = ["https://kdashboard.${local.internal_domain}/oauth2/callback"]
            enablePassword = false
            providers      = local.casdoor_oauth_providers
            signinMethods  = local.casdoor_signin_methods
            signupItems    = []
            grantTypes     = ["authorization_code", "refresh_token"]
            tags           = []
          },
          {
            owner          = "admin"
            name           = "kubero-oidc"
            createdTime    = "2025-01-01T00:00:00Z"
            displayName    = "Kubero OIDC"
            organization   = "built-in"
            clientId       = "kubero-oidc"
            clientSecret   = local.kubero_oidc_client_secret
            redirectUris   = ["https://kcloud.${local.internal_domain}/auth/callback"]
            enablePassword = false
            providers      = local.casdoor_oauth_providers
            signinMethods  = local.casdoor_signin_methods
            signupItems    = []
            grantTypes     = ["authorization_code", "refresh_token"]
            tags           = []
          }
        ] : []
      )
    })
  }
}

# Casdoor Helm Release
resource "helm_release" "casdoor" {
  count = local.casdoor_enabled ? 1 : 0

  name             = "casdoor"
  repository       = "oci://registry-1.docker.io/casbin"
  chart            = "casdoor-helm-charts"
  version          = "v1.570.0"
  namespace        = data.kubernetes_namespace.platform.metadata[0].name
  create_namespace = false
  timeout          = 300 # Match other Helm releases
  wait             = true

  values = [
    yamlencode({
      replicaCount = 1

      image = {
        repository = "casbin"
        name       = "casdoor"
        tag        = "v1.570.0"
        pullPolicy = "IfNotPresent"
      }

      # Wait for PostgreSQL before starting Casdoor (max 120s timeout)
      initContainers = [
        {
          name  = "wait-for-postgres"
          image = "busybox:1.36"
          command = [
            "sh", "-c",
            "timeout=120; elapsed=0; until nc -z postgresql.platform.svc.cluster.local 5432; do echo \"waiting for PostgreSQL... ($elapsed/$timeout s)\"; sleep 2; elapsed=$((elapsed+2)); if [ $elapsed -ge $timeout ]; then echo 'TIMEOUT: PostgreSQL not available'; exit 1; fi; done"
          ]
        }
      ]

      # Casdoor app.conf - ALL config must be in this string (INI format)
      # The helm chart ignores separate "database" map, only uses "config" string
      config = <<-EOT
appname = casdoor
httpport = 8000
origin = https://${local.casdoor_domain}
staticBaseUrl = https://cdn.casbin.org

# Required for Beego to parse request body (fixes "unexpected end of JSON input" login bug)
# Reference: https://github.com/casdoor/casdoor/issues/3224
copyrequestbody = true

# Database configuration
driverName = postgres
dataSourceName = user=postgres password=${var.vault_postgres_password} host=postgresql.platform.svc.cluster.local port=5432 dbname=casdoor sslmode=disable
dbName = casdoor
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

      # Mount init_data.json to root directory as file (per Casdoor K8s docs)
      # Ref: https://casdoor.org/docs/deployment/data-initialization#for-kubernetes
      extraVolumeMounts = [
        {
          name      = "init-data"
          mountPath = "/init_data.json"
          subPath   = "init_data.json"
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

  lifecycle {
    # Password validation: empty is allowed (uses default), but if set must be secure
    precondition {
      condition     = var.casdoor_admin_password == "" || length(var.casdoor_admin_password) >= 12
      error_message = "casdoor_admin_password must be at least 12 characters (or empty to use Chart default)."
    }
    precondition {
      condition     = length(var.vault_postgres_password) >= 16
      error_message = "vault_postgres_password (for Casdoor DB) must be at least 16 characters."
    }
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

output "casdoor_admin_password" {
  value       = local.casdoor_enabled ? var.casdoor_admin_password : null
  description = "Casdoor admin password (from 1Password via GitHub Secret)"
  sensitive   = true
}

# TRIGGER_DEPLOYMENT: Force CI to run terraform plan/apply
