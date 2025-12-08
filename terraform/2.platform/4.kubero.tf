# Phase 2.4: Kubero (GitOps PaaS Controller)
# Installation method: kubectl_manifest from local YAML files
# Source: https://github.com/kubero-dev/kubero-operator
#
# Architecture:
# 1. operator.yaml → CRDs + Operator Deployment (in kubero-operator-system namespace)
# 2. Kubero CR → Kubero UI deployment (in kubero namespace)
#
# Note: We use kubectl provider (gavinbunney/kubectl) because it supports
# server-side apply and doesn't require CRDs to exist at plan time.

# ============================================================
# Deploy Kubero Operator (CRDs + Controller) using kubectl_manifest
# This handles multi-document YAML automatically
# ============================================================
data "kubectl_file_documents" "kubero_operator" {
  content = file("${path.module}/manifests/kubero/operator.yaml")
}

resource "kubectl_manifest" "kubero_operator" {
  for_each  = data.kubectl_file_documents.kubero_operator.manifests
  yaml_body = each.value

  # Don't wait for rollout - CRDs don't have rollout status
  wait_for_rollout = false

  # Server-side apply handles large CRDs better
  server_side_apply = true
  force_conflicts   = true
}

# ============================================================
# Kubero Namespace (for UI and applications)
# ============================================================
resource "kubernetes_namespace" "kubero" {
  metadata {
    name = "kubero"
  }

  depends_on = [kubectl_manifest.kubero_operator]
}

# ============================================================
# Kubero Session Secret
# ============================================================
resource "random_id" "kubero_session_secret" {
  byte_length = 32
}

# ============================================================
# Kubero Custom Resource (deploys UI via operator)
# ============================================================
resource "kubectl_manifest" "kubero_instance" {
  yaml_body = yamlencode({
    apiVersion = "application.kubero.dev/v1alpha1"
    kind       = "Kubero"
    metadata = {
      name      = "kubero"
      namespace = kubernetes_namespace.kubero.metadata[0].name
    }
    spec = {
      replicaCount = 1
      image = {
        repository = "ghcr.io/kubero-dev/kubero/kubero"
        tag        = "latest"
        pullPolicy = "Always"
      }
      service = {
        type = "ClusterIP"
        port = 2000
      }
      ingress = {
        enabled   = true
        className = "nginx"
        annotations = {
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
        }
        hosts = [{
          host = "i-kcloud.${var.base_domain}"
          paths = [{
            path     = "/"
            pathType = "Prefix"
          }]
        }]
        tls = [{
          secretName = "kubero-ui-tls"
          hosts      = ["i-kcloud.${var.base_domain}"]
        }]
      }
      kubero = {
        namespace  = "kubero"
        context    = "inClusterContext"
        sessionKey = random_id.kubero_session_secret.hex
        auth = {
          github = {
            enabled = false
          }
        }
        config = {
          kubero = {
            readonly = false
            admin = {
              disabled = false
            }
          }
          clusterissuer = "letsencrypt-prod"
        }
      }
    }
  })

  # Wait for operator to be ready first
  depends_on = [
    kubectl_manifest.kubero_operator,
    kubernetes_namespace.kubero
  ]

  # Use server-side apply for CRD instances
  server_side_apply = true
  force_conflicts   = true
}

# ============================================================
# Outputs
# ============================================================
output "kubero_ui_url" {
  value       = "https://i-kcloud.${var.base_domain}"
  description = "Kubero UI URL"
}

output "kubero_session_secret" {
  value       = random_id.kubero_session_secret.hex
  description = "Kubero session secret (for reference)"
  sensitive   = true
}
