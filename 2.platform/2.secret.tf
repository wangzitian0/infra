# Vault (Secrets Management) - Phase 1: Deployment Only
# Namespace: platform
# Access: https://i-secrets.{internal_domain}
# Storage: Raft integrated storage with PVC (HA enabled)
#
# MANUAL INIT REQUIRED after first deployment:
#   kubectl exec -n platform vault-0 -- vault operator init
#   # Save the unseal keys and root token securely!
#   kubectl exec -n platform vault-0 -- vault operator unseal <key1>
#   kubectl exec -n platform vault-0 -- vault operator unseal <key2>
#   kubectl exec -n platform vault-0 -- vault operator unseal <key3>

# Platform namespace
resource "kubernetes_namespace" "platform" {
  metadata {
    name = "platform"
    labels = {
      layer = "L2"
    }
  }
}

locals {
  vault_config = <<-EOT
    ui = true

    listener "tcp" {
      address     = "0.0.0.0:8200"
      tls_disable = "true"
    }

    storage "raft" {
      path = "/vault/data"
    }

    service_registration "kubernetes" {}
  EOT
}

# Helm release for Vault with Raft HA storage
resource "helm_release" "vault" {
  name             = "vault"
  namespace        = kubernetes_namespace.platform.metadata[0].name
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  version          = var.vault_chart_version
  create_namespace = false
  timeout          = 600

  cleanup_on_fail = true

  values = [
    yamlencode({
      global = {
        tlsDisable = true
      }
      server = {
        image = {
          repository = "hashicorp/vault"
          tag        = var.vault_image_tag
        }
        ha = {
          enabled  = true
          replicas = 1
          raft = {
            enabled   = true
            setNodeId = true
          }
          config = local.vault_config
        }
        dataStorage = {
          enabled      = true
          size         = "1Gi"
          storageClass = "local-path-retain"
        }
        auditStorage = {
          enabled = false
        }
        service = {
          type = "ClusterIP"
        }
      }
      injector = {
        enabled = true
      }
    })
  ]

  depends_on = [kubernetes_namespace.platform]
}

# Ingress for Vault UI/API
resource "kubernetes_ingress_v1" "vault" {
  metadata {
    name      = "vault-ingress"
    namespace = kubernetes_namespace.platform.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts       = ["i-secrets.${local.internal_domain}"]
      secret_name = "vault-tls"
    }

    rule {
      host = "i-secrets.${local.internal_domain}"
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "vault"
              port {
                number = 8200
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.vault]
}

output "vault_ui" {
  value       = "https://i-secrets.${local.internal_domain}"
  description = "Vault UI/HTTP endpoint"
}

output "vault_internal_endpoint" {
  value       = "vault.platform.svc.cluster.local:8200"
  description = "Cluster-internal Vault service endpoint"
}

# =============================================================
# Phase 2 (Future PR): Auto-init via Kubernetes Job
# Phase 3 (Future PR): Backup CronJobs (daily/weekly snapshots)
# =============================================================
