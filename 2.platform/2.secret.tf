# Vault (Secrets Management)
# Namespace: platform
# Storage: PostgreSQL backend (HA via advisory locks)
# Features: Agent Injector enabled, Auto-initialization with keys in K8s Secret

locals {
  vault_storage_conn = "postgresql://vault:${var.vault_postgres_password}@postgresql.platform.svc.cluster.local:5432/vault?sslmode=disable"
  vault_config       = <<-EOT
    ui = true

    listener "tcp" {
      address     = "0.0.0.0:8200"
      tls_disable = "true"
    }

    storage "postgresql" {
      connection_url = "${local.vault_storage_conn}"
      ha_enabled     = "true"
    }
  EOT
}

# Helm release for Vault with PostgreSQL backend and Agent Injector
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
            enabled = false
          }
          config = local.vault_config
        }
        dataStorage = {
          enabled = false
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

  depends_on = [helm_release.postgresql]
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
      sleep 10
      
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
