# Portal SSO Gate - OAuth2-Proxy backed by Casdoor OIDC
# Provides a forward-auth middleware for Vault/Dashboard/Kubero Ingresses.
# Retry: 2025-12-17 trigger apply
#
# Status: Atlantis has enable_portal_sso_gate=true, ready to deploy
#
# Rollout guidance:
# 1) Deploy Casdoor (with GitHub OAuth creds) and ensure https://sso.<internal_domain> works.
# 2) Create a Casdoor application for the portal gate and set TF_VAR_casdoor_portal_client_id/secret.
# 3) Set enable_portal_sso_gate=true and apply to gate the portals.

locals {
  casdoor_enabled_for_gate = nonsensitive(var.github_oauth_client_id) != "" && nonsensitive(var.github_oauth_client_secret) != ""
  portal_auth_host         = "auth.${local.internal_domain}"
  casdoor_issuer           = "https://sso.${local.internal_domain}"
}

resource "terraform_data" "portal_sso_precheck" {
  input = {
    enabled = local.portal_sso_gate_enabled
  }

  lifecycle {
    precondition {
      condition     = !local.portal_sso_gate_enabled || local.casdoor_enabled_for_gate
      error_message = "enable_portal_sso_gate=true 需要先启用 Casdoor（github_oauth_client_id/secret）。"
    }
  }
}

resource "random_password" "portal_cookie_secret" {
  count   = local.portal_sso_gate_enabled ? 1 : 0
  length  = 32
  special = false
}

resource "helm_release" "portal_auth" {
  count = local.portal_sso_gate_enabled ? 1 : 0

  name       = "portal-auth"
  repository = "https://oauth2-proxy.github.io/manifests"
  chart      = "oauth2-proxy"
  version    = "7.12.7"
  namespace  = data.kubernetes_namespace.platform.metadata[0].name
  timeout    = 300
  wait       = true

  values = [
    yamlencode({
      # Wait for Casdoor OIDC to be ready (max 120s timeout)
      initContainers = [
        {
          name  = "wait-for-casdoor"
          image = "busybox:1.36"
          command = [
            "sh", "-c",
            "t=120;e=0;until wget -q --spider http://casdoor.platform.svc.cluster.local:8000/;do echo \"waiting for Casdoor... ($e/$t s)\";sleep 2;e=$((e+2));[ $e -ge $t ]&&exit 1;done"
          ]
        }
      ]

      config = {
        clientID     = var.casdoor_portal_client_id
        clientSecret = local.casdoor_portal_gate_client_secret
        cookieSecret = random_password.portal_cookie_secret[0].result
      }

      extraArgs = {
        provider                    = "oidc"
        "oidc-issuer-url"           = local.casdoor_issuer
        email-domain                = "*"
        cookie-domain               = ".${local.internal_domain}"
        cookie-secure               = "true"
        cookie-samesite             = "lax"
        upstream                    = "static://202"
        set-xauthrequest            = "true"
        reverse-proxy               = "true"
        skip-provider-button        = "true"
        "redirect-url"              = "https://${local.portal_auth_host}/oauth2/callback"
        "whitelist-domain"          = ".${local.internal_domain}"
        "pass-authorization-header" = "true"
        "scope"                     = "openid profile email"
      }

      ingress = {
        enabled   = true
        className = "traefik"
        hosts     = [local.portal_auth_host]
        path      = "/"
        pathType  = "Prefix"
        annotations = {
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
        }
        tls = [{
          secretName = "portal-auth-tls"
          hosts      = [local.portal_auth_host]
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

      # Health probes
      livenessProbe = {
        enabled = true
        path    = "/ping"
      }
      readinessProbe = {
        enabled = true
        path    = "/ping"
      }
    })
  ]

  depends_on = [
    terraform_data.portal_sso_precheck,
    data.kubernetes_namespace.platform,
    helm_release.casdoor
  ]
}

resource "kubernetes_manifest" "portal_auth_middleware_platform" {
  count = local.portal_sso_gate_enabled ? 1 : 0

  manifest = {
    apiVersion = "traefik.io/v1alpha1"
    kind       = "Middleware"
    metadata = {
      name      = "portal-auth"
      namespace = data.kubernetes_namespace.platform.metadata[0].name
    }
    spec = {
      forwardAuth = {
        address             = "http://portal-auth-oauth2-proxy.${data.kubernetes_namespace.platform.metadata[0].name}.svc.cluster.local/"
        trustForwardHeader  = false
        authResponseHeaders = ["X-Auth-Request-User", "X-Auth-Request-Email"]
      }
    }
  }

  depends_on = [
    helm_release.portal_auth
  ]
}



output "portal_sso_gate_enabled" {
  value       = local.portal_sso_gate_enabled
  description = "Whether the Casdoor-backed portal SSO gate (OAuth2-Proxy) is enabled."
  sensitive   = true
}

output "portal_auth_url" {
  value       = local.portal_sso_gate_enabled ? "https://${local.portal_auth_host}/" : "disabled"
  description = "OAuth2-Proxy endpoint for portal SSO gate."
  sensitive   = true
}
