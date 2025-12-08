# Phase 2.4: Kubero (GitOps PaaS Controller)
# Installation method: kubernetes_manifest from local YAML files
# Source: https://github.com/kubero-dev/kubero-operator
#
# Architecture:
# 1. operator.yaml → CRDs + Operator Deployment (in kubero-operator-system namespace)
# 2. Kubero CR → Kubero UI deployment (in kubero namespace)
#
# Note: We don't use helm_release because Kubero doesn't publish to a Helm repo

# ============================================================
# Parse multi-document YAML files into individual resources
# ============================================================
locals {
  # Split operator.yaml into individual resources
  operator_raw_docs = [
    for doc in split("\n---\n", file("${path.module}/manifests/kubero/operator.yaml"))
    : trimspace(doc)
  ]

  # Filter out empty documents and parse YAML
  operator_manifests = [
    for doc in local.operator_raw_docs
    : yamldecode(doc) if length(doc) > 0 && !startswith(doc, "#")
  ]
}

# ============================================================
# Deploy Kubero Operator (CRDs + Controller)
# ============================================================
resource "kubernetes_manifest" "kubero_operator" {
  for_each = { for idx, manifest in local.operator_manifests : "${manifest.kind}-${try(manifest.metadata.name, idx)}" => manifest }

  manifest = each.value

  # Handle CRDs first, then other resources
  depends_on = []
}

# ============================================================
# Kubero Namespace (for UI and applications)
# ============================================================
resource "kubernetes_namespace" "kubero" {
  metadata {
    name = "kubero"
  }

  depends_on = [kubernetes_manifest.kubero_operator]
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
resource "kubernetes_manifest" "kubero_instance" {
  manifest = {
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
        namespace  = kubernetes_namespace.kubero.metadata[0].name
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
  }

  depends_on = [
    kubernetes_manifest.kubero_operator,
    kubernetes_namespace.kubero
  ]
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
