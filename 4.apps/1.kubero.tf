# Phase 2.4: Kubero (GitOps PaaS Controller)
# Installation method: kubectl_manifest from local YAML files
# Source: https://github.com/kubero-dev/kubero-operator
#
# Architecture:
# 1. operator.yaml → CRDs + Operator Deployment (in kubero-operator-system namespace)
# 2. Kubero CR → Kubero UI deployment (in kubero namespace)
#
# NOTE: Two-phase deployment to avoid race condition:
# - Phase 1: Create operator namespace (kubernetes_namespace)
# - Phase 2: Apply operator manifests (kubectl_manifest with depends_on)

# ============================================================
# Parse multi-document YAML file statically
# ============================================================
locals {
  # Read and split the operator.yaml into individual documents
  operator_yaml_raw_content = file("${path.module}/manifests/kubero/operator.yaml")

  # Replace namespace AND cluster-scoped resource names for multi-tenant deployment
  # ClusterRole/ClusterRoleBinding are cluster-scoped, need unique names per environment
  operator_yaml_raw = replace(
    replace(
      replace(
        local.operator_yaml_raw_content,
        "kubero-operator-system", "kubero-operator-system-${var.environment}"
      ),
      "kuberorole", "kuberorole-${var.environment}"
    ),
    "kuberorolebinding", "kuberorolebinding-${var.environment}"
  )


  # Split by document separator and filter empty docs
  operator_docs = [
    for doc in split("\n---\n", local.operator_yaml_raw)
    : trimspace(doc) if length(trimspace(doc)) > 0 && !startswith(trimspace(doc), "#")
  ]

  # Separate namespace manifest from other manifests
  # The namespace is typically the first document (kind: Namespace)
  operator_namespace_docs = [
    for doc in local.operator_docs
    : doc if can(regex("(?m)^kind:\\s*Namespace", doc))
  ]

  operator_other_docs = [
    for doc in local.operator_docs
    : doc if !can(regex("(?m)^kind:\\s*Namespace", doc))
  ]
}

# ============================================================
# Phase 1: Create operator namespace first
# ============================================================
resource "kubernetes_namespace" "kubero_operator_system" {
  metadata {
    name = "kubero-operator-system-${var.environment}"
    labels = {
      "control-plane" = "controller-manager"
      "layer"         = "L4"
    }
  }
}

# ============================================================
# Phase 2: Deploy Kubero Operator (CRDs + Controller)
# Now that namespace exists, apply all other operator manifests
# ============================================================
resource "kubectl_manifest" "kubero_operator" {
  count     = length(local.operator_other_docs)
  yaml_body = local.operator_other_docs[count.index]

  # Server-side apply handles large CRDs better
  server_side_apply = true
  force_conflicts   = true

  # Don't wait for rollout - CRDs don't have rollout status
  wait_for_rollout = false

  # CRITICAL: Wait for namespace to be created first
  depends_on = [kubernetes_namespace.kubero_operator_system]
}

# ============================================================
# Kubero Namespace (for UI and applications)
# ============================================================
resource "kubernetes_namespace" "kubero" {
  metadata {
    name = "kubero-${var.environment}"
    labels = {
      "layer" = "L4"
    }
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
        tag        = var.kubero_ui_image_tag
        pullPolicy = var.kubero_ui_image_pull_policy
      }
      service = {
        type = "ClusterIP"
        port = 2000
      }
      # Health probes
      livenessProbe = {
        httpGet = {
          path = "/"
          port = 2000
        }
        initialDelaySeconds = 30
        periodSeconds       = 10
      }
      readinessProbe = {
        httpGet = {
          path = "/"
          port = 2000
        }
        initialDelaySeconds = 5
        periodSeconds       = 5
      }
      # NOTE: persistence block is ignored by Kubero Helm chart
      # The correct location is kubero.database (see below)
      ingress = {
        enabled   = true
        className = "traefik"
        annotations = merge(
          {
            "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
          },
          # Middleware Reference:
          # Using cross-namespace reference enabled in L1 (namespace-name@provider)
          local.portal_sso_gate_enabled ? {
            "traefik.ingress.kubernetes.io/router.middlewares" = "${var.namespaces["platform"]}-portal-auth@kubernetescrd"
          } : {}
        )
        hosts = [{
          host = "kcloud.${local.internal_domain}"
          paths = [{
            path     = "/"
            pathType = "Prefix"
          }]
        }]
        tls = [{
          secretName = "kubero-ui-tls"
          hosts      = ["kcloud.${local.internal_domain}"]
        }]
      }
      kubero = {
        namespace  = "kubero-${var.environment}"
        context    = "inClusterContext"
        sessionKey = random_id.kubero_session_secret.hex
        auth = {
          github = {
            enabled = false
          }
        }
        # Database PVC config - this is where storageClassName belongs!
        database = {
          storageClassName = "local-path"
          accessModes      = ["ReadWriteOnce"]
          size             = "1Gi"
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

  # Wait for operator and namespace to be ready
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
  value       = "https://kcloud.${local.internal_domain}"
  description = "Kubero UI URL"
}

output "kubero_session_secret" {
  value       = random_id.kubero_session_secret.hex
  description = "Kubero session secret (for reference)"
  sensitive   = true
}
