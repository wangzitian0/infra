# Homer Portal - Unified Dashboard for All Services
# Namespace: platform
# URL: https://portal.{internal_domain} (e.g., portal.zitian.party)
#
# Purpose: Beautiful landing page with quick links to all infrastructure services
# Features:
# - Categorized service links (Platform, Apps, Tools)
# - Search functionality
# - Mobile-friendly responsive design
# - Can optionally be protected by Portal SSO Gate

locals {
  portal_enabled = var.enable_portal_dashboard
  portal_domain  = "home.${local.internal_domain}"

  # Homer configuration (YAML)
  homer_config = yamlencode({
    title    = "Infrastructure Portal"
    subtitle = "🔒 Protected by SSO - Quick access to all services"
    logo     = "https://cdn.casbin.org/img/casbin.svg"

    # Optional: Header links
    links = [
      {
        name   = "GitHub Repo"
        icon   = "fab fa-github"
        url    = "https://github.com/wangzitian0/infra"
        target = "_blank"
      }
    ]

    # Service categories
    services = [
      {
        name = "Platform Services"
        icon = "fas fa-server"
        items = [
          {
            name     = "Vault (OIDC Login)"
            logo     = "https://www.vectorlogo.zone/logos/vaultproject/vaultproject-icon.svg"
            subtitle = "Click OIDC → Login with GitHub"
            tag      = "recommended"
            url      = "https://secrets.${local.internal_domain}"
            target   = "_blank"
          },
          {
            name     = "Casdoor SSO"
            logo     = "https://cdn.casbin.org/img/casbin.svg"
            subtitle = "Login with GitHub OAuth"
            tag      = "sso"
            url      = "https://sso.${local.internal_domain}/login"
            target   = "_blank"
          },
          {
            name     = "Kubernetes Dashboard"
            logo     = "https://raw.githubusercontent.com/kubernetes/kubernetes/master/logo/logo.svg"
            subtitle = "Cluster Management UI"
            tag      = "k8s"
            url      = "https://kdashboard.${local.internal_domain}"
            target   = "_blank"
          },
          {
            name     = "Casdoor Admin"
            logo     = "https://cdn.casbin.org/img/casbin.svg"
            subtitle = "User & role management"
            tag      = "admin"
            url      = "https://sso.${local.internal_domain}"
            target   = "_blank"
          }
        ]
      },
      {
        name = "Emergency Access"
        icon = "fas fa-exclamation-triangle"
        items = [
          {
            name     = "Vault (Root Token)"
            logo     = "https://www.vectorlogo.zone/logos/vaultproject/vaultproject-icon.svg"
            subtitle = "⚠️ Break-glass when OIDC fails"
            tag      = "emergency"
            url      = "https://secrets.${local.internal_domain}/ui/vault/auth?with=token"
            target   = "_blank"
          }
        ]
      },
      {
        name = "Application Services"
        icon = "fas fa-cloud"
        items = [
          {
            name     = "Kubero"
            logo     = "https://www.kubero.dev/img/logo.svg"
            subtitle = "Cloud PaaS Platform"
            tag      = "paas"
            url      = "https://kcloud.${local.internal_domain}"
            target   = "_blank"
          }
          # Add more apps here as they are deployed
        ]
      },
      {
        name = "Developer Tools"
        icon = "fas fa-tools"
        items = [
          {
            name     = "GitHub"
            logo     = "https://github.githubassets.com/images/modules/logos_page/GitHub-Mark.png"
            subtitle = "Infrastructure Code Repository"
            tag      = "git"
            url      = "https://github.com/wangzitian0/infra"
            target   = "_blank"
          }
        ]
      }
    ]
  })
}

# ConfigMap for Homer configuration
resource "kubernetes_config_map" "homer_config" {
  count = local.portal_enabled ? 1 : 0

  metadata {
    name      = "homer-config"
    namespace = data.kubernetes_namespace.platform.metadata[0].name
  }

  data = {
    "config.yml" = local.homer_config
  }
}

# Homer Deployment
resource "kubernetes_deployment" "homer" {
  count = local.portal_enabled ? 1 : 0

  metadata {
    name      = "homer"
    namespace = data.kubernetes_namespace.platform.metadata[0].name
    labels = {
      app = "homer"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "homer"
      }
    }

    template {
      metadata {
        labels = {
          app = "homer"
        }
      }

      spec {
        container {
          name  = "homer"
          image = "b4bz/homer:latest"

          port {
            container_port = 8080
            name           = "http"
          }

          volume_mount {
            name       = "config"
            mount_path = "/www/assets/config.yml"
            sub_path   = "config.yml"
          }

          resources {
            limits = {
              cpu    = "100m"
              memory = "128Mi"
            }
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 10
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 8080
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map.homer_config[0].metadata[0].name
          }
        }
      }
    }
  }
}

# Service for Homer
resource "kubernetes_service" "homer" {
  count = local.portal_enabled ? 1 : 0

  metadata {
    name      = "homer"
    namespace = data.kubernetes_namespace.platform.metadata[0].name
  }

  spec {
    selector = {
      app = "homer"
    }

    port {
      port        = 80
      target_port = 8080
      name        = "http"
    }

    type = "ClusterIP"
  }
}

# Ingress for Homer
resource "kubernetes_ingress_v1" "homer" {
  count = local.portal_enabled ? 1 : 0

  metadata {
    name      = "homer-ingress"
    namespace = data.kubernetes_namespace.platform.metadata[0].name
    annotations = merge(
      {
        "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      },
      # Always protect Portal with SSO Gate
      local.portal_sso_gate_enabled ? {
        "traefik.ingress.kubernetes.io/router.middlewares" = "platform-portal-auth@kubernetescrd"
      } : {}
    )
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts       = [local.portal_domain]
      secret_name = "homer-tls"
    }

    rule {
      host = local.portal_domain
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.homer[0].metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_deployment.homer]
}

# Output
output "portal_url" {
  value       = local.portal_enabled ? "https://${local.portal_domain}" : "Portal not enabled"
  description = "Homer Portal Dashboard URL"
}
