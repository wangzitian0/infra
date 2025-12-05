# Phase 1.3: Kubernetes Dashboard (Web UI for Cluster Management)
# Namespace: kube-system (standard namespace for cluster-level components)
# Access: NodePort on port 30443

# Deploy Kubernetes Dashboard using official manifests
resource "kubernetes_manifest" "dashboard_namespace" {
  manifest = {
    apiVersion = "v1"
    kind       = "Namespace"
    metadata = {
      name = "kubernetes-dashboard"
    }
  }
}

# ServiceAccount for Dashboard
resource "kubernetes_service_account" "dashboard" {
  metadata {
    name      = "kubernetes-dashboard"
    namespace = kubernetes_manifest.dashboard_namespace.manifest.metadata.name
  }
}

# Deploy Dashboard using Helm
resource "helm_release" "kubernetes_dashboard" {
  name       = "kubernetes-dashboard"
  repository = "https://kubernetes.github.io/dashboard/"
  chart      = "kubernetes-dashboard"
  version    = "7.10.0"
  namespace  = kubernetes_manifest.dashboard_namespace.manifest.metadata.name

  values = [
    yamlencode({
      app = {
        ingress = {
          enabled = false
        }
      }

      # Expose via NodePort for easy access
      kong = {
        proxy = {
          http = {
            enabled     = true
            servicePort = 8443
          }
        }
        service = {
          type = "NodePort"
          nodePorts = {
            http = 30443
          }
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
    kubernetes_manifest.dashboard_namespace
  ]
}

# Admin ServiceAccount for full cluster access
resource "kubernetes_service_account" "dashboard_admin" {
  metadata {
    name      = "dashboard-admin"
    namespace = kubernetes_manifest.dashboard_namespace.manifest.metadata.name
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
    namespace = kubernetes_manifest.dashboard_namespace.manifest.metadata.name
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.dashboard_admin.metadata[0].name
    }
  }

  type = "kubernetes.io/service-account-token"

  depends_on = [kubernetes_service_account.dashboard_admin]
}

# Outputs
output "dashboard_url" {
  value       = "https://<VPS_IP>:30443"
  description = "Kubernetes Dashboard URL (replace <VPS_IP> with your server IP)"
}

output "dashboard_token_command" {
  value       = "kubectl -n kubernetes-dashboard get secret dashboard-admin-token -o jsonpath='{.data.token}' | base64 -d"
  description = "Command to get dashboard admin token"
}

output "dashboard_port_forward_command" {
  value       = "kubectl -n kubernetes-dashboard port-forward svc/kubernetes-dashboard-kong-proxy 8443:443"
  description = "Alternative: Access dashboard via port-forward on https://localhost:8443"
}
