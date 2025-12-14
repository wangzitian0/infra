# Casdoor - Unified SSO Platform
# Namespace: platform
# URL: sso.{internal_domain} (e.g., sso.zitian.party)
# Database: L1 Platform PostgreSQL (vault database, separate casdoor schema)
#
# Purpose: Centralized authentication for all L2+ services
# - GitHub/Google OAuth as identity providers
# - OIDC provider for Vault, Dashboard, Kubero, etc.
#
# Architecture:
# - Helm release deploys Casdoor with minimal init_data (admin user + built-in org/app only)
# - REST API provider manages applications AFTER Casdoor is running
# - This allows declarative management: Terraform can create/update/delete apps
#
# Why REST API instead of casdoor provider?
# - casdoor provider requires Casdoor to be running during `terraform plan`
# - This creates chicken-and-egg problem: can't plan before first deploy
# - REST API provider only connects during apply, after Helm release is ready

locals {
  # Use nonsensitive() to avoid tainting downstream outputs as sensitive.
  casdoor_enabled     = nonsensitive(var.github_oauth_client_id) != "" && nonsensitive(var.github_oauth_client_secret) != ""
  casdoor_domain      = "sso.${local.internal_domain}"
  casdoor_api_url     = "https://${local.casdoor_domain}"
  portal_gate_enabled = local.casdoor_enabled && var.enable_portal_sso_gate

  # Built-in application credentials (for API authentication)
  casdoor_builtin_client_id     = "admin"
  casdoor_builtin_client_secret = var.casdoor_admin_password

  # OIDC Client Secrets: prefer manual values from 1Password, fallback to auto-generated
  casdoor_portal_gate_client_secret = var.casdoor_portal_client_secret != "" ? var.casdoor_portal_client_secret : (local.portal_gate_enabled ? random_password.portal_gate_client_secret[0].result : "")
  vault_oidc_client_secret          = var.casdoor_vault_oidc_client_secret != "" ? var.casdoor_vault_oidc_client_secret : (local.portal_gate_enabled ? random_password.vault_oidc_client_secret[0].result : "")
  dashboard_oidc_client_secret      = var.casdoor_dashboard_oidc_client_secret != "" ? var.casdoor_dashboard_oidc_client_secret : (local.portal_gate_enabled ? random_password.dashboard_oidc_client_secret[0].result : "")
  kubero_oidc_client_secret         = var.casdoor_kubero_oidc_client_secret != "" ? var.casdoor_kubero_oidc_client_secret : (local.portal_gate_enabled ? random_password.kubero_oidc_client_secret[0].result : "")
}

# ============================================================
# Random Password Generation
# ============================================================

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

# ============================================================
# REST API Provider for Casdoor
# ============================================================

provider "restapi" {
  alias = "casdoor"

  uri                   = local.casdoor_api_url
  write_returns_object  = true
  create_returns_object = true

  headers = {
    "Content-Type" = "application/json"
  }

  debug = false
}

# ============================================================
# Casdoor Helm Release (Minimal Init Data)
# ============================================================

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
          password      = var.casdoor_admin_password
          passwordType  = "plain"
          isAdmin       = true
          isGlobalAdmin = true
        }
      ]
      # Built-in application for API access
      applications = [
        {
          owner          = "admin"
          name           = "app-built-in"
          createdTime    = "2025-01-01T00:00:00Z"
          displayName    = "Built-in Application"
          organization   = "built-in"
          clientId       = local.casdoor_builtin_client_id
          clientSecret   = local.casdoor_builtin_client_secret
          redirectUris   = ["https://${local.casdoor_domain}/callback"]
          enablePassword = true
          providers      = []
          signinMethods  = []
          signupItems    = []
          grantTypes     = ["authorization_code", "refresh_token", "client_credentials"]
          tags           = []
        }
      ]
    })
  }
}

resource "helm_release" "casdoor" {
  count = local.casdoor_enabled ? 1 : 0

  name             = "casdoor"
  repository       = "oci://registry-1.docker.io/casbin"
  chart            = "casdoor-helm-charts"
  version          = "v1.570.0"
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
        tag        = "v1.570.0"
        pullPolicy = "IfNotPresent"
      }

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

      config = <<-EOT
appname = casdoor
httpport = 8000
origin = https://${local.casdoor_domain}
staticBaseUrl = https://cdn.casbin.org
copyrequestbody = true
driverName = postgres
dataSourceName = user=postgres password=${var.vault_postgres_password} host=postgresql.platform.svc.cluster.local port=5432 dbname=casdoor sslmode=disable
dbName = casdoor
EOT

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

      startupProbe = {
        httpGet = {
          path = "/"
          port = "http"
        }
        failureThreshold = 12
        periodSeconds    = 10
      }

      livenessProbe = {
        httpGet = {
          path = "/"
          port = "http"
        }
        failureThreshold = 3
        periodSeconds    = 10
      }

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

  depends_on = [data.kubernetes_namespace.platform]

  lifecycle {
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

# ============================================================
# Casdoor Resources via REST API
# ============================================================

# GitHub OAuth Provider
resource "restapi_object" "casdoor_provider_github" {
  count    = local.casdoor_enabled ? 1 : 0
  provider = restapi.casdoor

  path         = "/api/add-provider?clientId=${local.casdoor_builtin_client_id}&clientSecret=${local.casdoor_builtin_client_secret}"
  id_attribute = "data/name"

  data = jsonencode({
    owner        = "built-in"
    name         = "provider_github"
    displayName  = "GitHub"
    category     = "OAuth"
    type         = "GitHub"
    clientId     = var.github_oauth_client_id
    clientSecret = var.github_oauth_client_secret
  })

  update_path  = "/api/update-provider?clientId=${local.casdoor_builtin_client_id}&clientSecret=${local.casdoor_builtin_client_secret}"
  destroy_path = "/api/delete-provider?clientId=${local.casdoor_builtin_client_id}&clientSecret=${local.casdoor_builtin_client_secret}"

  depends_on = [helm_release.casdoor, cloudflare_record.casdoor]
}

# Portal Gate Application (OAuth2-Proxy)
resource "restapi_object" "casdoor_app_portal_gate" {
  count    = local.portal_gate_enabled ? 1 : 0
  provider = restapi.casdoor

  path         = "/api/add-application?clientId=${local.casdoor_builtin_client_id}&clientSecret=${local.casdoor_builtin_client_secret}"
  id_attribute = "data/name"

  data = jsonencode({
    owner          = "admin"
    name           = "portal-gate"
    displayName    = "Portal SSO Gate"
    organization   = "built-in"
    clientId       = var.casdoor_portal_client_id
    clientSecret   = local.casdoor_portal_gate_client_secret
    redirectUris   = ["https://auth.${local.internal_domain}/oauth2/callback"]
    enablePassword = false
    grantTypes     = ["authorization_code", "refresh_token"]
    providers = [
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
    signinMethods = [
      {
        name        = "OAuth"
        displayName = "OAuth"
        rule        = "All"
      }
    ]
    tags = ["terraform-managed"]
  })

  update_path  = "/api/update-application?clientId=${local.casdoor_builtin_client_id}&clientSecret=${local.casdoor_builtin_client_secret}"
  destroy_path = "/api/delete-application?clientId=${local.casdoor_builtin_client_id}&clientSecret=${local.casdoor_builtin_client_secret}"

  depends_on = [restapi_object.casdoor_provider_github]
}

# Vault OIDC Application
resource "restapi_object" "casdoor_app_vault_oidc" {
  count    = local.portal_gate_enabled ? 1 : 0
  provider = restapi.casdoor

  path         = "/api/add-application?clientId=${local.casdoor_builtin_client_id}&clientSecret=${local.casdoor_builtin_client_secret}"
  id_attribute = "data/name"

  data = jsonencode({
    owner          = "admin"
    name           = "vault-oidc"
    displayName    = "Vault OIDC"
    organization   = "built-in"
    clientId       = "vault-oidc"
    clientSecret   = local.vault_oidc_client_secret
    redirectUris   = ["https://secrets.${local.internal_domain}/ui/vault/auth/oidc/oidc/callback"]
    enablePassword = false
    grantTypes     = ["authorization_code", "refresh_token"]
    providers = [
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
    signinMethods = [
      {
        name        = "OAuth"
        displayName = "OAuth"
        rule        = "All"
      }
    ]
    tags = ["terraform-managed"]
  })

  update_path  = "/api/update-application?clientId=${local.casdoor_builtin_client_id}&clientSecret=${local.casdoor_builtin_client_secret}"
  destroy_path = "/api/delete-application?clientId=${local.casdoor_builtin_client_id}&clientSecret=${local.casdoor_builtin_client_secret}"

  depends_on = [restapi_object.casdoor_provider_github]
}

# Dashboard OIDC Application
resource "restapi_object" "casdoor_app_dashboard_oidc" {
  count    = local.portal_gate_enabled ? 1 : 0
  provider = restapi.casdoor

  path         = "/api/add-application?clientId=${local.casdoor_builtin_client_id}&clientSecret=${local.casdoor_builtin_client_secret}"
  id_attribute = "data/name"

  data = jsonencode({
    owner          = "admin"
    name           = "dashboard-oidc"
    displayName    = "Dashboard OIDC"
    organization   = "built-in"
    clientId       = "dashboard-oidc"
    clientSecret   = local.dashboard_oidc_client_secret
    redirectUris   = ["https://kdashboard.${local.internal_domain}/oauth2/callback"]
    enablePassword = false
    grantTypes     = ["authorization_code", "refresh_token"]
    providers = [
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
    signinMethods = [
      {
        name        = "OAuth"
        displayName = "OAuth"
        rule        = "All"
      }
    ]
    tags = ["terraform-managed"]
  })

  update_path  = "/api/update-application?clientId=${local.casdoor_builtin_client_id}&clientSecret=${local.casdoor_builtin_client_secret}"
  destroy_path = "/api/delete-application?clientId=${local.casdoor_builtin_client_id}&clientSecret=${local.casdoor_builtin_client_secret}"

  depends_on = [restapi_object.casdoor_provider_github]
}

# Kubero OIDC Application
resource "restapi_object" "casdoor_app_kubero_oidc" {
  count    = local.portal_gate_enabled ? 1 : 0
  provider = restapi.casdoor

  path         = "/api/add-application?clientId=${local.casdoor_builtin_client_id}&clientSecret=${local.casdoor_builtin_client_secret}"
  id_attribute = "data/name"

  data = jsonencode({
    owner          = "admin"
    name           = "kubero-oidc"
    displayName    = "Kubero OIDC"
    organization   = "built-in"
    clientId       = "kubero-oidc"
    clientSecret   = local.kubero_oidc_client_secret
    redirectUris   = ["https://kcloud.${local.internal_domain}/auth/callback"]
    enablePassword = false
    grantTypes     = ["authorization_code", "refresh_token"]
    providers = [
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
    signinMethods = [
      {
        name        = "OAuth"
        displayName = "OAuth"
        rule        = "All"
      }
    ]
    tags = ["terraform-managed"]
  })

  update_path  = "/api/update-application?clientId=${local.casdoor_builtin_client_id}&clientSecret=${local.casdoor_builtin_client_secret}"
  destroy_path = "/api/delete-application?clientId=${local.casdoor_builtin_client_id}&clientSecret=${local.casdoor_builtin_client_secret}"

  depends_on = [restapi_object.casdoor_provider_github]
}

# ============================================================
# Outputs
# ============================================================

output "casdoor_url" {
  value       = local.casdoor_enabled ? "https://${local.casdoor_domain}" : "Casdoor not enabled (missing OAuth credentials)"
  description = "Casdoor SSO URL"
}

output "casdoor_admin_password" {
  value       = local.casdoor_enabled ? var.casdoor_admin_password : null
  description = "Casdoor admin password (from 1Password via GitHub Secret)"
  sensitive   = true
}

output "casdoor_api_info" {
  value = local.casdoor_enabled ? {
    api_url   = local.casdoor_api_url
    client_id = local.casdoor_builtin_client_id
    note      = "Client secret is the same as casdoor_admin_password"
  } : null
  description = "Casdoor API connection info for debugging"
}

output "casdoor_oidc_clients" {
  value = local.portal_gate_enabled ? {
    portal_gate = {
      client_id     = var.casdoor_portal_client_id
      client_secret = local.casdoor_portal_gate_client_secret
      redirect_uri  = "https://auth.${local.internal_domain}/oauth2/callback"
    }
    vault_oidc = {
      client_id     = "vault-oidc"
      client_secret = local.vault_oidc_client_secret
      redirect_uri  = "https://secrets.${local.internal_domain}/ui/vault/auth/oidc/oidc/callback"
    }
    dashboard_oidc = {
      client_id     = "dashboard-oidc"
      client_secret = local.dashboard_oidc_client_secret
      redirect_uri  = "https://kdashboard.${local.internal_domain}/oauth2/callback"
    }
    kubero_oidc = {
      client_id     = "kubero-oidc"
      client_secret = local.kubero_oidc_client_secret
      redirect_uri  = "https://kcloud.${local.internal_domain}/auth/callback"
    }
  } : null
  description = "Casdoor OIDC client credentials for downstream services"
  sensitive   = true
}

# TRIGGER_DEPLOYMENT: Force CI to run terraform plan/apply
