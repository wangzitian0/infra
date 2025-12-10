# Vault (Secrets Management)
# Namespace: platform
# Storage: Raft integrated storage with PVC (HA enabled)
# Features: Agent Injector, Auto-initialization, Automated Backups

# Platform namespace (moved from deleted 1.postgres.tf)
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

# Helm release for Vault with Raft HA storage and Agent Injector
resource "helm_release" "vault" {
  name             = "vault"
  namespace        = kubernetes_namespace.platform.metadata[0].name
  repository       = "https://helm.releases.hashicorp.com"
  chart            = "vault"
  version          = var.vault_chart_version
  create_namespace = false
  timeout          = 900

  # cleanup_on_fail helps with failed deployments
  # NOTE: Do NOT use force_update or replace=true permanently - they cause Vault recreation on every apply
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

# ============================================================
# Vault Auto-Initialization via Kubernetes Job
# ============================================================

# ServiceAccount for init job with secret creation permission
resource "kubernetes_service_account" "vault_init" {
  metadata {
    name      = "vault-init"
    namespace = kubernetes_namespace.platform.metadata[0].name
  }
}

resource "kubernetes_role" "vault_init" {
  metadata {
    name      = "vault-init"
    namespace = kubernetes_namespace.platform.metadata[0].name
  }
  rule {
    api_groups = [""]
    resources  = ["secrets"]
    verbs      = ["create", "get", "update", "patch"]
  }
}

resource "kubernetes_role_binding" "vault_init" {
  metadata {
    name      = "vault-init"
    namespace = kubernetes_namespace.platform.metadata[0].name
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.vault_init.metadata[0].name
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.vault_init.metadata[0].name
    namespace = kubernetes_namespace.platform.metadata[0].name
  }
}

# Init job - runs once after Vault deployment
resource "kubernetes_job" "vault_init" {
  metadata {
    name      = "vault-init-${helm_release.vault.metadata[0].revision}"
    namespace = kubernetes_namespace.platform.metadata[0].name
  }
  spec {
    ttl_seconds_after_finished = 300
    template {
      metadata {}
      spec {
        service_account_name = kubernetes_service_account.vault_init.metadata[0].name
        container {
          name    = "init"
          image   = "bitnami/kubectl:latest"
          command = ["/bin/sh", "-c"]
          args = [<<-EOT
            set -e
            VAULT_ADDR="http://vault.platform.svc.cluster.local:8200"
            
            echo "Waiting for Vault to be ready..."
            # Use /v1/sys/init instead of /v1/sys/health - health returns 503 when uninitialized
            until wget -qO- $VAULT_ADDR/v1/sys/init 2>/dev/null | grep -q initialized; do
              echo "Vault not ready, waiting..."
              sleep 5
            done
            echo "Vault is ready!"
            
            # Check if already initialized
            INIT_STATUS=$(wget -qO- $VAULT_ADDR/v1/sys/init 2>/dev/null || echo '{"initialized":true}')
            if echo "$INIT_STATUS" | grep -q '"initialized":false'; then
              echo "Initializing Vault..."
              INIT_RESPONSE=$(wget -qO- --post-data='{"secret_shares":5,"secret_threshold":3}' \
                --header="Content-Type: application/json" \
                $VAULT_ADDR/v1/sys/init)
              
              echo "$INIT_RESPONSE" > /tmp/init.json
              
              # Create K8s secret with init keys
              echo "Storing unseal keys in Kubernetes Secret..."
              kubectl create secret generic vault-unseal-keys -n platform \
                --from-file=init-keys=/tmp/init.json \
                --dry-run=client -o yaml | kubectl apply -f -
              
              # Extract and unseal with first 3 keys
              echo "Unsealing Vault..."
              KEY1=$(cat /tmp/init.json | sed 's/.*"keys_base64":\["\([^"]*\)".*/\1/')
              KEY2=$(cat /tmp/init.json | sed 's/.*"keys_base64":\["[^"]*","\([^"]*\)".*/\1/')
              KEY3=$(cat /tmp/init.json | sed 's/.*"keys_base64":\["[^"]*","[^"]*","\([^"]*\)".*/\1/')
              
              wget -qO- --post-data="{\"key\":\"$KEY1\"}" --header="Content-Type: application/json" $VAULT_ADDR/v1/sys/unseal
              wget -qO- --post-data="{\"key\":\"$KEY2\"}" --header="Content-Type: application/json" $VAULT_ADDR/v1/sys/unseal
              wget -qO- --post-data="{\"key\":\"$KEY3\"}" --header="Content-Type: application/json" $VAULT_ADDR/v1/sys/unseal
              
              rm /tmp/init.json
              echo "Vault initialized and unsealed successfully!"
            else
              echo "Vault already initialized, skipping init"
              
              # Check if sealed and try to unseal
              SEAL_STATUS=$(wget -qO- $VAULT_ADDR/v1/sys/seal-status 2>/dev/null || echo '{"sealed":false}')
              if echo "$SEAL_STATUS" | grep -q '"sealed":true'; then
                echo "Vault is sealed, attempting unseal from stored keys..."
                KEYS_JSON=$(kubectl get secret -n platform vault-unseal-keys -o jsonpath='{.data.init-keys}' | base64 -d)
                KEY1=$(echo "$KEYS_JSON" | sed 's/.*"keys_base64":\["\([^"]*\)".*/\1/')
                KEY2=$(echo "$KEYS_JSON" | sed 's/.*"keys_base64":\["[^"]*","\([^"]*\)".*/\1/')
                KEY3=$(echo "$KEYS_JSON" | sed 's/.*"keys_base64":\["[^"]*","[^"]*","\([^"]*\)".*/\1/')
                
                wget -qO- --post-data="{\"key\":\"$KEY1\"}" --header="Content-Type: application/json" $VAULT_ADDR/v1/sys/unseal || true
                wget -qO- --post-data="{\"key\":\"$KEY2\"}" --header="Content-Type: application/json" $VAULT_ADDR/v1/sys/unseal || true
                wget -qO- --post-data="{\"key\":\"$KEY3\"}" --header="Content-Type: application/json" $VAULT_ADDR/v1/sys/unseal || true
                echo "Unseal attempted"
              else
                echo "Vault is already unsealed"
              fi
            fi
          EOT
          ]
        }
        restart_policy = "OnFailure"
      }
    }
  }
  depends_on = [helm_release.vault]

  # NOTE: Job runs async - do not wait. Verify manually: kubectl get jobs -n platform
}

# Backup PVC for Vault snapshots
resource "kubernetes_persistent_volume_claim" "vault_backup" {
  metadata {
    name      = "vault-backup"
    namespace = kubernetes_namespace.platform.metadata[0].name
  }
  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "local-path-retain"
    resources {
      requests = {
        storage = "2Gi"
      }
    }
  }
  depends_on = [kubernetes_namespace.platform]
}

# Daily backup CronJob (retain 3 days)
resource "kubernetes_cron_job_v1" "vault_backup_daily" {
  metadata {
    name      = "vault-backup-daily"
    namespace = kubernetes_namespace.platform.metadata[0].name
  }
  spec {
    schedule                      = "0 2 * * *"
    successful_jobs_history_limit = 3
    failed_jobs_history_limit     = 1
    job_template {
      metadata {}
      spec {
        template {
          metadata {}
          spec {
            service_account_name = "vault"
            container {
              name    = "backup"
              image   = "hashicorp/vault:${var.vault_image_tag}"
              command = ["/bin/sh", "-c"]
              args = [<<-EOT
                set -e
                export VAULT_ADDR="http://vault.platform.svc.cluster.local:8200"
                
                # Get root token from secret
                ROOT_TOKEN=$(cat /vault-keys/init-keys | jq -r '.root_token')
                export VAULT_TOKEN=$ROOT_TOKEN
                
                # Create snapshot
                BACKUP_FILE="/backup/daily-$(date +%Y%m%d-%H%M%S).snap"
                vault operator raft snapshot save $BACKUP_FILE
                echo "Backup saved to $BACKUP_FILE"
                
                # Cleanup old daily backups (keep 3 days)
                find /backup -name "daily-*.snap" -mtime +3 -delete
                echo "Cleaned up backups older than 3 days"
              EOT
              ]
              volume_mount {
                name       = "backup"
                mount_path = "/backup"
              }
              volume_mount {
                name       = "vault-keys"
                mount_path = "/vault-keys"
                read_only  = true
              }
            }
            volume {
              name = "backup"
              persistent_volume_claim {
                claim_name = kubernetes_persistent_volume_claim.vault_backup.metadata[0].name
              }
            }
            volume {
              name = "vault-keys"
              secret {
                secret_name = "vault-unseal-keys"
              }
            }
            restart_policy = "OnFailure"
          }
        }
      }
    }
  }
  depends_on = [kubernetes_job.vault_init, kubernetes_persistent_volume_claim.vault_backup]
}

# Weekly backup CronJob (retain 1 month / 4 weeks)
resource "kubernetes_cron_job_v1" "vault_backup_weekly" {
  metadata {
    name      = "vault-backup-weekly"
    namespace = kubernetes_namespace.platform.metadata[0].name
  }
  spec {
    schedule                      = "0 3 * * 0"
    successful_jobs_history_limit = 4
    failed_jobs_history_limit     = 1
    job_template {
      metadata {}
      spec {
        template {
          metadata {}
          spec {
            service_account_name = "vault"
            container {
              name    = "backup"
              image   = "hashicorp/vault:${var.vault_image_tag}"
              command = ["/bin/sh", "-c"]
              args = [<<-EOT
                set -e
                export VAULT_ADDR="http://vault.platform.svc.cluster.local:8200"
                
                # Get root token from secret
                ROOT_TOKEN=$(cat /vault-keys/init-keys | jq -r '.root_token')
                export VAULT_TOKEN=$ROOT_TOKEN
                
                # Create snapshot
                BACKUP_FILE="/backup/weekly-$(date +%Y%m%d-%H%M%S).snap"
                vault operator raft snapshot save $BACKUP_FILE
                echo "Backup saved to $BACKUP_FILE"
                
                # Cleanup old weekly backups (keep 4 weeks / 1 month)
                find /backup -name "weekly-*.snap" -mtime +28 -delete
                echo "Cleaned up backups older than 28 days"
              EOT
              ]
              volume_mount {
                name       = "backup"
                mount_path = "/backup"
              }
              volume_mount {
                name       = "vault-keys"
                mount_path = "/vault-keys"
                read_only  = true
              }
            }
            volume {
              name = "backup"
              persistent_volume_claim {
                claim_name = kubernetes_persistent_volume_claim.vault_backup.metadata[0].name
              }
            }
            volume {
              name = "vault-keys"
              secret {
                secret_name = "vault-unseal-keys"
              }
            }
            restart_policy = "OnFailure"
          }
        }
      }
    }
  }
  depends_on = [kubernetes_job.vault_init, kubernetes_persistent_volume_claim.vault_backup]
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
