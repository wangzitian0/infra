# Namespace: platform (Platform layer - shared with other platform services)
# Access: Ingress via kdashboard.{internal_domain}
# Note: Dashboard namespace merged into platform namespace

# ServiceAccount for Dashboard
resource "kubernetes_service_account" "dashboard" {
  metadata {
    name      = "kubernetes-dashboard"
    namespace = data.kubernetes_namespace.platform.metadata[0].name
  }
}

# Deploy Dashboard using Helm
resource "helm_release" "kubernetes_dashboard" {
  name       = "kubernetes-dashboard"
  repository = "https://kubernetes.github.io/dashboard/"
  chart      = "kubernetes-dashboard"
  version    = "7.10.0"
  namespace  = data.kubernetes_namespace.platform.metadata[0].name
  timeout    = 300
  wait       = true

  values = [
    yamlencode({
      app = {
        ingress = {
          enabled = false
        }
      }

      # Kong disabled (using Traefik Ingress directly)
      kong = {
        enabled = false
      }

      # App Ingress disabled (we create our own below)
      app = {
        ingress = {
          enabled = false
        }
      }

      # Enable metrics scraper
      metricsScraper = {
        enabled = true
      }

      # Resource limits
      api = {
        containers = {
          resources = {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
      }

      web = {
        containers = {
          resources = {
            requests = {
              cpu    = "50m"
              memory = "64Mi"
            }
            limits = {
              cpu    = "150m"
              memory = "128Mi"
            }
          }
        }
      }
    })
  ]

  # Data source dependency (data.kubernetes_namespace.platform) is implicit
}

# Ingress for Dashboard
resource "kubernetes_ingress_v1" "dashboard" {
  metadata {
    name      = "kubernetes-dashboard"
    namespace = data.kubernetes_namespace.platform.metadata[0].name
    annotations = merge(
      {
        "cert-manager.io/cluster-issuer"                      = "letsencrypt-prod"
        "traefik.ingress.kubernetes.io/router.tls"            = "true"
        "traefik.ingress.kubernetes.io/service.serversscheme" = "http"
      },
      local.portal_sso_gate_enabled ? {
        "traefik.ingress.kubernetes.io/router.middlewares" = "${data.kubernetes_namespace.platform.metadata[0].name}-portal-auth@kubernetescrd"
      } : {}
    )
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts       = ["kdashboard.${local.internal_domain}"]
      secret_name = "dashboard-tls"
    }

    rule {
      host = "kdashboard.${local.internal_domain}"
      http {
        # Auth Routes
        path {
          path      = "/api/v1/login"
          path_type = "Prefix"
          backend {
            service {
              name = "kubernetes-dashboard-auth"
              port {
                number = 8000
              }
            }
          }
        }
        path {
          path      = "/api/v1/csrftoken"
          path_type = "Prefix"
          backend {
            service {
              name = "kubernetes-dashboard-auth"
              port {
                number = 8000
              }
            }
          }
        }
        path {
          path      = "/api/v1/me"
          path_type = "Prefix"
          backend {
            service {
              name = "kubernetes-dashboard-auth"
              port {
                number = 8000
              }
            }
          }
        }

        # API Routes
        path {
          path      = "/api"
          path_type = "Prefix"
          backend {
            service {
              name = "kubernetes-dashboard-api"
              port {
                number = 8000
              }
            }
          }
        }

        # Web Route (Root)
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "kubernetes-dashboard-web"
              port {
                number = 8000
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.kubernetes_dashboard]
}

# ClusterRoleBinding for Dashboard API ServiceAccount (created by Helm chart)
# This allows the dashboard to view/manage cluster resources
resource "kubernetes_cluster_role_binding" "dashboard_api_admin" {
  metadata {
    name = "kubernetes-dashboard-api-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin" # Full access for dashboard API
  }

  subject {
    kind      = "ServiceAccount"
    name      = "kubernetes-dashboard-api"
    namespace = data.kubernetes_namespace.platform.metadata[0].name
  }

  depends_on = [helm_release.kubernetes_dashboard]
}

# Admin ServiceAccount for full cluster access (for manual token-based login)
resource "kubernetes_service_account" "dashboard_admin" {
  metadata {
    name      = "dashboard-admin"
    namespace = data.kubernetes_namespace.platform.metadata[0].name
  }

  depends_on = [helm_release.kubernetes_dashboard]
}

# ClusterRoleBinding for admin access
resource "kubernetes_cluster_role_binding" "dashboard_admin" {
  metadata {
    name = "dashboard-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.dashboard_admin.metadata[0].name
    namespace = kubernetes_service_account.dashboard_admin.metadata[0].namespace
  }

  depends_on = [kubernetes_service_account.dashboard_admin]
}

# Secret for admin token (Kubernetes 1.24+)
resource "kubernetes_secret" "dashboard_admin_token" {
  metadata {
    name      = "dashboard-admin-token"
    namespace = data.kubernetes_namespace.platform.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.dashboard_admin.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"

  depends_on = [kubernetes_service_account.dashboard_admin]
}

# Outputs
output "dashboard_url" {
  value       = "https://kdashboard.${local.internal_domain}"
  description = "Kubernetes Dashboard URL"
}

output "dashboard_token_command" {
  value       = "kubectl -n platform get secret dashboard-admin-token -o jsonpath='{.data.token}' | base64 -d"
  description = "Command to get dashboard admin token"
}

output "dashboard_port_forward_command" {
  value       = "kubectl -n platform port-forward svc/kubernetes-dashboard-web 8000:8000"
  description = "Access dashboard via port-forward on http://localhost:8000"
}
