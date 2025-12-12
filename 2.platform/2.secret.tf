# Vault (Secrets Management) - PostgreSQL Storage Backend
# Namespace: platform
# Access: https://secrets.{internal_domain}
# Storage: PostgreSQL (deployed in L1 as Platform PG)
#
# MANUAL INIT REQUIRED after first deployment:
#   kubectl exec -n platform vault-0 -- vault operator init
#   # Save the unseal keys and root token securely!
#   kubectl exec -n platform vault-0 -- vault operator unseal <key1>
#   kubectl exec -n platform vault-0 -- vault operator unseal <key2>
#   kubectl exec -n platform vault-0 -- vault operator unseal <key3>

# Platform namespace (created in L1 by 5.platform_pg.tf)
# Using data source to reference existing namespace
data "kubernetes_namespace" "platform" {
  metadata {
    name = "platform"
  }
}

locals {
  # PostgreSQL connection string for Vault storage backend
  vault_pg_connection = "postgres://postgres:${var.vault_postgres_password}@postgresql.platform.svc.cluster.local:5432/vault?sslmode=disable"

  vault_config = <<-EOT
    ui = true

    listener "tcp" {
      address     = "0.0.0.0:8200"
      tls_disable = "true"
    }

    storage "postgresql" {
      connection_url = "${local.vault_pg_connection}"
      table          = "vault_kv_store"
      ha_enabled     = true
      ha_table       = "vault_ha_locks"
    }

    service_registration "kubernetes" {}
  EOT
}

# Helm release for Vault with PostgreSQL storage backend
resource "helm_release" "vault" {
  name             = "vault"
  namespace        = data.kubernetes_namespace.platform.metadata[0].name
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  version          = var.vault_chart_version
  create_namespace = false
  timeout          = 120
  wait             = true
  wait_for_jobs    = true

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
          # Raft disabled - using PostgreSQL storage backend
          raft = {
            enabled = false
          }
          config = local.vault_config
        }
        # dataStorage not needed with PostgreSQL backend
        dataStorage = {
          enabled = false
        }
        auditStorage = {
          enabled      = true
          size         = "1Gi"
          storageClass = "local-path-retain"
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

  depends_on = [data.kubernetes_namespace.platform]
}

# Ingress for Vault UI/API
resource "kubernetes_ingress_v1" "vault" {
  metadata {
    name      = "vault-ingress"
    namespace = data.kubernetes_namespace.platform.metadata[0].name
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts       = ["secrets.${local.internal_domain}"]
      secret_name = "vault-tls"
    }

    rule {
      host = "secrets.${local.internal_domain}"
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
  value       = "https://secrets.${local.internal_domain}"
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
