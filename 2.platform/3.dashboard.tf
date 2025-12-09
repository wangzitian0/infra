# Phase 1.3: Kubernetes Dashboard (Web UI for Cluster Management)
# Namespace: platform (L2 layer - shared with other platform services)
# Access: Ingress via i-kdashboard.{base_domain}
# Note: Dashboard namespace merged into platform namespace

# ServiceAccount for Dashboard
resource "kubernetes_service_account" "dashboard" {
  metadata {
    name      = "kubernetes-dashboard"
    namespace = kubernetes_namespace.platform.metadata[0].name
  }
}

# Deploy Dashboard using Helm
resource "helm_release" "kubernetes_dashboard" {
  name       = "kubernetes-dashboard"
  repository = "https://kubernetes.github.io/dashboard/"
  chart      = "kubernetes-dashboard"
  version    = "7.10.0"
  namespace  = kubernetes_namespace.platform.metadata[0].name

  values = [
    yamlencode({
      app = {
        ingress = {
          enabled = false
        }
      }

      # Kong as internal gateway (no NodePort)
      kong = {
        proxy = {
          http = {
            enabled     = true
            servicePort = 8443
          }
        }
        service = {
          type = "ClusterIP"
        }
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

  depends_on = [
    kubernetes_namespace.platform
  ]
}

# Ingress for Dashboard (via Traefik ingress controller)
resource "kubernetes_ingress_v1" "dashboard" {
  metadata {
    name      = "kubernetes-dashboard"
    namespace = kubernetes_namespace.platform.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer"                        = "letsencrypt-prod"
      "traefik.ingress.kubernetes.io/router.tls"              = "true"
      "traefik.ingress.kubernetes.io/service.serversscheme"   = "https"
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts       = ["i-kdashboard.${var.base_domain}"]
      secret_name = "dashboard-tls"
    }

    rule {
      host = "i-kdashboard.${var.base_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "kubernetes-dashboard-kong-proxy"
              port {
                number = 443
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.kubernetes_dashboard]
}

# Admin ServiceAccount for full cluster access
resource "kubernetes_service_account" "dashboard_admin" {
  metadata {
    name      = "dashboard-admin"
    namespace = kubernetes_namespace.platform.metadata[0].name
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
    namespace = kubernetes_namespace.platform.metadata[0].name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.dashboard_admin.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"

  depends_on = [kubernetes_service_account.dashboard_admin]
}

# Outputs
output "dashboard_url" {
  value       = "https://i-kdashboard.${var.base_domain}"
  description = "Kubernetes Dashboard URL"
}

output "dashboard_token_command" {
  value       = "kubectl -n kubernetes-dashboard get secret dashboard-admin-token -o jsonpath='{.data.token}' | base64 -d"
  description = "Command to get dashboard admin token"
}

output "dashboard_port_forward_command" {
  value       = "kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443"
  description = "Alternative: Access dashboard via port-forward on https://localhost:8443"
}
