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

  # Force replacement when storage config changes (StatefulSet volumeClaimTemplates are immutable)
  force_update    = true
  replace         = true
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

# Auto-initialize Vault and store keys in K8s Secret
resource "null_resource" "vault_init" {
  depends_on = [helm_release.vault, kubernetes_ingress_v1.vault]

  triggers = {
    vault_release = helm_release.vault.metadata[0].revision
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      # Set kubeconfig
      export KUBECONFIG="${var.kubeconfig_path != "" ? var.kubeconfig_path : "~/.kube/config"}"
      
      # Wait for Vault pod to be ready
      echo "Waiting for Vault pod to be ready..."
      kubectl wait --for=condition=ready pod/vault-0 -n platform --timeout=300s || true
      sleep 15
      
      # Check if already initialized
      echo "Checking Vault initialization status..."
      INIT_STATUS=$(kubectl exec -n platform vault-0 -- vault status -format=json 2>/dev/null | jq -r '.initialized' || echo "false")
      
      if [ "$INIT_STATUS" = "false" ]; then
        echo "Initializing Vault..."
        kubectl exec -n platform vault-0 -- vault operator init -format=json > /tmp/vault-init.json
        
        echo "Storing unseal keys in K8s Secret..."
        kubectl create secret generic vault-unseal-keys -n platform \
          --from-file=init-keys=/tmp/vault-init.json \
          --dry-run=client -o yaml | kubectl apply -f -
        
        echo "Auto-unsealing Vault..."
        for i in 0 1 2; do
          KEY=$(jq -r ".unseal_keys_b64[$i]" /tmp/vault-init.json)
          kubectl exec -n platform vault-0 -- vault operator unseal $KEY
        done
        
        rm -f /tmp/vault-init.json
        echo "Vault initialized and unsealed successfully!"
      else
        echo "Vault already initialized, checking seal status..."
        SEALED=$(kubectl exec -n platform vault-0 -- vault status -format=json 2>/dev/null | jq -r '.sealed' || echo "true")
        if [ "$SEALED" = "true" ]; then
          echo "Vault is sealed, attempting to unseal from stored keys..."
          KEYS_JSON=$(kubectl get secret -n platform vault-unseal-keys -o jsonpath='{.data.init-keys}' | base64 -d)
          for i in 0 1 2; do
            KEY=$(echo "$KEYS_JSON" | jq -r ".unseal_keys_b64[$i]")
            kubectl exec -n platform vault-0 -- vault operator unseal $KEY || true
          done
        else
          echo "Vault is already unsealed."
        fi
      fi
    EOT
  }
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
  depends_on = [null_resource.vault_init]
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
  depends_on = [null_resource.vault_init]
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
