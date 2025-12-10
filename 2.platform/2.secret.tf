# Vault (Secrets Management)
# Namespace: platform
# Storage: Raft integrated storage with PVC (no external DB dependency)
# Features: Agent Injector enabled, HA-ready Raft backend

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

# Helm release for Vault with Raft storage and Agent Injector
resource "helm_release" "vault" {
  name             = "vault"
  namespace        = kubernetes_namespace.platform.metadata[0].name
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  version          = var.vault_chart_version
  create_namespace = false
  timeout          = 900

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
      hosts       = ["i-secrets.${var.base_domain}"]
      secret_name = "vault-tls"
    }

    rule {
      host = "i-secrets.${var.base_domain}"
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
  value       = "https://i-secrets.${var.base_domain}"
  description = "Vault UI/HTTP endpoint"
}

output "vault_internal_endpoint" {
  value       = "vault.platform.svc.cluster.local:8200"
  description = "Cluster-internal Vault service endpoint"
}

