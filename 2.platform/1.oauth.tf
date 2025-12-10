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
  # Use internal_domain for OAuth, fallback to base_domain if not set
  oauth_domain = var.internal_domain != "" ? var.internal_domain : var.base_domain
}

resource "random_password" "oauth2_cookie_secret" {
  length  = 32
  special = false
}

# OAuth2-Proxy Helm Release
resource "helm_release" "oauth2_proxy" {
  name       = "oauth2-proxy"
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = "7.12.7"
  namespace  = kubernetes_namespace.platform.metadata[0].name

  values = [
    yamlencode({
      config = {
        clientID     = var.github_oauth_client_id
        clientSecret = var.github_oauth_client_secret
        cookieSecret = random_password.oauth2_cookie_secret.result
      }

      extraArgs = {
        provider                  = "github"
        email-domain              = "*"
        cookie-domain             = ".${local.oauth_domain}"
        cookie-secure             = "true"
        cookie-samesite           = "lax"
        set-xauthrequest          = "true"
        reverse-proxy             = "true"
        pass-access-token         = "true"
        pass-authorization-header = "true"
        skip-provider-button      = "true"
        # Restrict to specific GitHub org (optional)
        github-org = var.github_oauth_org
      }

      ingress = {
        enabled   = true
        className = "traefik"
        hosts     = ["auth.${local.oauth_domain}"]
        path      = "/"
        pathType  = "Prefix"
        annotations = {
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
        }
        tls = [{
          secretName = "oauth2-proxy-tls"
          hosts      = ["auth.${local.oauth_domain}"]
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

  depends_on = [kubernetes_namespace.platform]
}

# Outputs
output "oauth2_proxy_url" {
  value       = "https://auth.${local.oauth_domain}"
  description = "OAuth2-Proxy authentication endpoint"
}

output "oauth2_proxy_auth_url" {
  value       = "https://auth.${local.oauth_domain}/oauth2/auth"
  description = "URL for Traefik forward-auth"
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
  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "oauth2-proxy-auth"
      namespace = kubernetes_namespace.platform.metadata[0].name
    }
    spec = {
      forwardAuth = {
        address             = "http://oauth2-proxy.${kubernetes_namespace.platform.metadata[0].name}.svc.cluster.local/oauth2/auth"
        trustForwardHeader  = true
        authResponseHeaders = ["X-Auth-Request-User", "X-Auth-Request-Email", "X-Auth-Request-Access-Token"]
      }
    }
  }

  depends_on = [helm_release.oauth2_proxy]
}
