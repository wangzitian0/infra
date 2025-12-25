# Phase 2.5: Kubero (GitOps PaaS Controller)
# Migrated from 4.apps/1.kubero.tf
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
  operator_yaml_raw_content = file("${path.module}/manifests-kubero/kubero/operator.yaml")

  # NOTE: L4 control plane is SINGLETON (no env suffix)
  # ClusterRole/ClusterRoleBinding names from upstream manifest are used as-is
  operator_yaml_raw = local.operator_yaml_raw_content

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

# Import existing namespace created by previous apps-prod apply
import {
  to = kubernetes_namespace.kubero_operator_system
  id = "kubero-operator-system"
}

resource "kubernetes_namespace" "kubero_operator_system" {
  metadata {
    name = "kubero-operator-system" # L4 control plane: singleton
    labels = {
      "control-plane" = "controller-manager"
      "layer"         = "platform"
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

# Import existing namespace created by previous apps-prod apply
import {
  to = kubernetes_namespace.kubero
  id = "kubero"
}

resource "kubernetes_namespace" "kubero" {
  metadata {
    name = "kubero" # Control plane: singleton
    labels = {
      "layer" = "platform"
    }
  }

  depends_on = [kubectl_manifest.kubero_operator]
}

# NOTE: Kubero random secrets (Session/Webhook) are now generated and stored in Vault 
# by the Platform layer (92.vault-kubero.tf).
# Apps layer retrieves them via Vault Agent Injection for the pods,
# and via data source for the CR spec.

data "vault_kv_secret_v2" "kubero" {
  mount = local.vault_kv_mount

  name = "kubero"

  lifecycle {
    postcondition {
      condition = (
        can(self.data["KUBERO_SESSION_KEY"]) &&
        can(self.data["KUBERO_WEBHOOK_SECRET"]) &&
        (
          !local.casdoor_oidc_enabled ||
          (
            can(self.data["KUBERO_OIDC_CLIENT_ID"]) &&
            can(self.data["KUBERO_OIDC_CLIENT_SECRET"]) &&
            self.data["KUBERO_OIDC_CLIENT_SECRET"] != ""
          )
        )
      )
      error_message = "Kubero secrets not found in Vault. Ensure Platform 92.vault-kubero.tf has been applied."
    }
  }

  # Depend on vault_kv_secret_v2.kubero from 92.vault-kubero.tf
  depends_on = [vault_kv_secret_v2.kubero]
}

# ============================================================
# Kubero Secrets (required by deployment, not created by Helm chart)
# Sync'd from Vault to satisfy operator dependencies while maintaining SSOT
# ============================================================

# Import existing secret created by previous apps-prod apply
import {
  to = kubernetes_secret.kubero_secrets
  id = "kubero/kubero-secrets"
}

resource "kubernetes_secret" "kubero_secrets" {
  metadata {
    name      = "kubero-secrets"
    namespace = kubernetes_namespace.kubero.metadata[0].name
  }

  data = {
    KUBERO_WEBHOOK_SECRET = data.vault_kv_secret_v2.kubero.data["KUBERO_WEBHOOK_SECRET"]
    KUBERO_SESSION_KEY    = data.vault_kv_secret_v2.kubero.data["KUBERO_SESSION_KEY"]
  }

  depends_on = [kubernetes_namespace.kubero, data.vault_kv_secret_v2.kubero]
}

# ============================================================
# Kubero ServiceAccount (for Vault Auth)
# ============================================================
import {
  to = kubernetes_service_account.kubero
  id = "kubero/kubero" # Control plane: singleton
}

resource "kubernetes_service_account" "kubero" {
  metadata {
    name      = "kubero"
    namespace = kubernetes_namespace.kubero.metadata[0].name
  }

  depends_on = [kubernetes_namespace.kubero]
}

# ============================================================
# Kubero Custom Resource (deploys UI via operator)
# ============================================================

# Import existing CR created by previous apps-prod apply
# Format: apiVersion//kind//name//namespace
import {
  to = kubectl_manifest.kubero_instance
  id = "application.kubero.dev/v1alpha1//Kubero//kubero//kubero"
}

resource "kubectl_manifest" "kubero_instance" {
  yaml_body = yamlencode({
    apiVersion = "application.kubero.dev/v1alpha1"
    kind       = "Kubero"
    metadata = {
      name      = "kubero"
      namespace = kubernetes_namespace.kubero.metadata[0].name
      annotations = {
        # Vault Agent Injector Annotations
        # Note: If the operator doesn't pass these to the UI pod, we may need 
        # to use kubernetes_annotations resource to target the deployment.
        "vault.hashicorp.com/agent-inject"              = "true"
        "vault.hashicorp.com/role"                      = "kubero"
        "vault.hashicorp.com/agent-inject-secret-env"   = "${local.vault_kv_mount}/data/data/kubero"
        "vault.hashicorp.com/agent-inject-template-env" = <<-EOT
          {{- with secret "${local.vault_kv_mount}/data/data/kubero" -}}
          export KUBERO_WEBHOOK_SECRET="{{ .Data.data.KUBERO_WEBHOOK_SECRET }}"
          export KUBERO_SESSION_KEY="{{ .Data.data.KUBERO_SESSION_KEY }}"
          {{- end -}}
        EOT
      }
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
        # Kubero uses native OIDC; avoid forwardAuth to prevent double auth.
        annotations = {
          "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
        }
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
        namespace  = "kubero" # Control plane: singleton
        context    = "inClusterContext"
        sessionKey = data.vault_kv_secret_v2.kubero.data["KUBERO_SESSION_KEY"]
        auth = {
          github = {
            enabled = false
          }
          oauth2 = local.casdoor_oidc_enabled ? {
            enabled     = true
            name        = "Casdoor"
            id          = data.vault_kv_secret_v2.kubero.data["KUBERO_OIDC_CLIENT_ID"]
            authUrl     = "https://${local.casdoor_domain}/login/oauth/authorize"
            tokenUrl    = "https://${local.casdoor_domain}/api/login/oauth/access_token"
            secret      = data.vault_kv_secret_v2.kubero.data["KUBERO_OIDC_CLIENT_SECRET"]
            callbackUrl = "https://kcloud.${local.internal_domain}/auth/callback"
            scopes      = "openid profile email"
            } : {
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

  # Wait for operator, namespace, and SA to be ready
  depends_on = [
    kubectl_manifest.kubero_operator,
    kubernetes_namespace.kubero,
    kubernetes_service_account.kubero,
    data.vault_kv_secret_v2.kubero
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
  value     = data.vault_kv_secret_v2.kubero.data["KUBERO_SESSION_KEY"]
  sensitive = true
}
