# OAuth2 Proxy - Unified Authentication Gateway for Internal Services
# Namespace: platform
# URL: auth.{internal_domain} (e.g., auth.zitian.party)
# Protects: All internal i-* services via forward-auth
#
# SETUP REQUIRED:
# 1. Create GitHub OAuth App: https://github.com/settings/developers
#    - Homepage URL: https://auth.{internal_domain}
#    - Callback URL: https://auth.{internal_domain}/oauth2/callback
# 2. Set TF variables: github_oauth_client_id, github_oauth_client_secret
# 3. (Optional) Restrict to GitHub org: github_oauth_org

locals {
  # OAuth2-Proxy is only deployed when GitHub OAuth credentials are provided
  # Use nonsensitive() to avoid tainting downstream booleans/outputs as sensitive.
  oauth2_proxy_enabled = nonsensitive(var.github_oauth_client_id) != "" && nonsensitive(var.github_oauth_client_secret) != ""
}

resource "random_password" "oauth2_cookie_secret" {
  count   = local.oauth2_proxy_enabled ? 1 : 0
  length  = 32
  special = false
}

# OAuth2-Proxy Helm Release (conditional: requires GitHub OAuth credentials)
resource "helm_release" "oauth2_proxy" {
  count = local.oauth2_proxy_enabled ? 1 : 0

  name       = "oauth2-proxy"
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = "7.12.7"
  namespace  = data.kubernetes_namespace.platform.metadata[0].name

  values = [
    yamlencode({
      config = {
        clientID     = var.github_oauth_client_id
        clientSecret = var.github_oauth_client_secret
        cookieSecret = random_password.oauth2_cookie_secret[0].result
      }

      extraArgs = merge(
        {
          provider             = "github"
          email-domain         = "*"
          cookie-domain        = ".${local.internal_domain}"
          cookie-secure        = "true"
          cookie-samesite      = "lax"
          upstream             = "static://202"
          set-xauthrequest     = "true"
          reverse-proxy        = "true"
          skip-provider-button = "true"
          "redirect-url"       = "https://auth.${local.internal_domain}/oauth2/callback"
          "whitelist-domain"   = ".${local.internal_domain}"
        },
        # Restrict to specific GitHub org (optional)
        var.github_oauth_org != "" ? { "github-org" = var.github_oauth_org } : {}
      )

      ingress = {
        enabled   = true
        className = "traefik"
        hosts     = ["auth.${local.internal_domain}"]
        path      = "/"
        pathType  = "Prefix"
        annotations = {
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
        }
        tls = [{
          secretName = "oauth2-proxy-tls"
          hosts      = ["auth.${local.internal_domain}"]
        }]
      }

      resources = {
        requests = {
          cpu    = "50m"
          memory = "64Mi"
        }
        limits = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }
    })
  ]

  depends_on = [data.kubernetes_namespace.platform]
}

# Outputs
output "oauth2_proxy_enabled" {
  value       = local.oauth2_proxy_enabled
  description = "Whether OAuth2-Proxy is deployed (requires GitHub OAuth credentials)"
  sensitive   = true
}

output "oauth2_proxy_url" {
  value       = local.oauth2_proxy_enabled ? "https://auth.${local.internal_domain}" : "Not deployed (missing GitHub OAuth credentials)"
  description = "OAuth2-Proxy authentication endpoint"
  sensitive   = true
}

output "oauth2_proxy_auth_url" {
  value       = local.oauth2_proxy_enabled ? "https://auth.${local.internal_domain}/oauth2/auth" : "Not deployed"
  description = "URL for Traefik forward-auth"
  sensitive   = true
}

# =============================================================
# To protect a service with OAuth2-Proxy, add these annotations
# to its Ingress:
#
# annotations = {
#   "traefik.ingress.kubernetes.io/router.middlewares" = 
#     "platform-oauth2-proxy-auth@kubernetescrd"
# }
#
# Or create a Traefik ForwardAuth middleware:
# =============================================================

resource "kubernetes_manifest" "oauth2_auth_middleware" {
  count = local.oauth2_proxy_enabled ? 1 : 0

  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "oauth2-proxy-auth"
      namespace = data.kubernetes_namespace.platform.metadata[0].name
    }
    spec = {
      forwardAuth = {
        address             = "http://oauth2-proxy.${data.kubernetes_namespace.platform.metadata[0].name}.svc.cluster.local/"
        trustForwardHeader  = false
        authResponseHeaders = ["X-Auth-Request-User", "X-Auth-Request-Email"]
      }
    }
  }

  depends_on = [helm_release.oauth2_proxy]
}

# Separate middleware in kubero namespace to avoid relying on Traefik cross-namespace references.
resource "kubernetes_manifest" "oauth2_auth_middleware_kubero" {
  count = local.oauth2_proxy_enabled ? 1 : 0

  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "oauth2-proxy-auth"
      namespace = kubernetes_namespace.kubero.metadata[0].name
    }
    spec = {
      forwardAuth = {
        address             = "http://oauth2-proxy.${data.kubernetes_namespace.platform.metadata[0].name}.svc.cluster.local/"
        trustForwardHeader  = false
        authResponseHeaders = ["X-Auth-Request-User", "X-Auth-Request-Email"]
      }
    }
  }

  depends_on = [helm_release.oauth2_proxy, kubernetes_namespace.kubero]
}
