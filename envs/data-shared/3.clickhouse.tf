# Purpose: OLAP analytics database for applications

#
# Architecture (VSO Pattern - Issue #351):
# - random_password generates password on first deploy
# - vault_kv_secret_v2 stores password in Vault (SSOT)
# - VaultStaticSecret syncs Vault → K8s Secret (via VSO)
# - Helm uses existingSecret to read from K8s Secret
# - Provider uses random_password with ignore_changes for state recovery
#
# Pattern: Altinity ClickHouse Operator + ClickHouseInstallation CR
# Namespace: per-env (data-staging, data-prod)
#
# Scalability:
# Current: Single node (shards=1, replicaCount=1, zookeeper=disabled)
# Future: Enable sharding/replication (requires ZooKeeper)

# =============================================================================
# Password Generation
# =============================================================================

resource "random_password" "clickhouse" {
  length  = 32
  special = false
}

# =============================================================================
# Vault KV Storage (store password - SSOT)
# =============================================================================

resource "vault_kv_secret_v2" "clickhouse" {
  mount               = data.terraform_remote_state.platform.outputs.vault_kv_mount
  name                = data.terraform_remote_state.platform.outputs.vault_db_secrets["clickhouse"]
  delete_all_versions = true

  data_json = jsonencode({
    username = "default"
    password = random_password.clickhouse.result
    host     = "clickhouse.${local.namespace_name}.svc.cluster.local"
    port     = "9000"
    database = "default"
  })

  depends_on = [kubernetes_namespace.data]

  lifecycle {
    # Don't overwrite existing password in Vault during state recovery
    ignore_changes = [data_json]
  }
}

# =============================================================================
# VaultStaticSecret - Syncs Vault KV → K8s Secret (via VSO)
# =============================================================================

resource "kubectl_manifest" "clickhouse_vault_secret" {
  yaml_body = yamlencode({
    apiVersion = "secrets.hashicorp.com/v1beta1"
    kind       = "VaultStaticSecret"
    metadata = {
      name      = "clickhouse-credentials"
      namespace = local.namespace_name
    }
    spec = {
      type  = "kv-v2"
      mount = data.terraform_remote_state.platform.outputs.vault_kv_mount
      path  = data.terraform_remote_state.platform.outputs.vault_db_secrets["clickhouse"]
      destination = {
        name   = "clickhouse-credentials"
        create = true
      }
      refreshAfter = "1h"
      vaultAuthRef = "default"
    }
  })

  depends_on = [vault_kv_secret_v2.clickhouse, kubectl_manifest.vault_auth]
}

# Wait for VSO to sync the secret before ClickHouseInstallation uses it
resource "time_sleep" "wait_for_clickhouse_secret" {
  create_duration = "15s"
  depends_on      = [kubectl_manifest.clickhouse_vault_secret]
}

# =============================================================================
# ClickHouse Provider Configuration
# =============================================================================
# Note: Provider uses random_password directly. On state recovery, this may
# cause auth errors until manually updated. ClickHouseInstallation uses the same
# password, while Vault/VSO remain the SSOT for apps.

provider "clickhousedbops" {
  host     = var.clickhouse_host != "" ? var.clickhouse_host : "clickhouse.${local.namespace_name}.svc.cluster.local"
  port     = 8123
  protocol = "http"

  auth_config = {
    strategy = "basicauth"
    username = "default"
    password = random_password.clickhouse.result
  }
}

# =============================================================================
# ClickHouse Operator (Altinity)
# =============================================================================

resource "helm_release" "clickhouse_operator" {
  name             = "clickhouse-operator"
  namespace        = local.namespace_name # Per-env: data-staging, data-prod
  repository       = "https://altinity.github.io/clickhouse-operator/"
  chart            = "altinity-clickhouse-operator"
  version          = "0.25.6"
  create_namespace = false
  timeout          = 300 # Consistent with PR #170 standard (was 600s)
  wait             = true
  wait_for_jobs    = true

  lifecycle {
    postcondition {
      condition     = self.status == "deployed"
      error_message = "ClickHouse operator Helm release failed to deploy. Check pod logs and events."
    }
  }

  depends_on = [kubernetes_namespace.data]
}

# Wait for ClickHouse Operator CRD to be established
resource "time_sleep" "wait_for_clickhouse_crd" {
  create_duration = "30s"

  depends_on = [helm_release.clickhouse_operator]
}

# =============================================================================
# ClickHouseInstallation CR (single shard/replica)
# =============================================================================

resource "kubectl_manifest" "clickhouse_installation" {
  yaml_body = yamlencode({
    apiVersion = "clickhouse.altinity.com/v1"
    kind       = "ClickHouseInstallation"
    metadata = {
      name      = "clickhouse"
      namespace = local.namespace_name
      labels = {
        module = "data"
        env    = local.env_name
      }
    }
    spec = {
      configuration = {
        users = {
          "default/password"            = random_password.clickhouse.result
          "default/password_sha256_hex" = sha256(random_password.clickhouse.result)
          "default/networks/ip" = [
            "0.0.0.0/0"
          ]
        }
        clusters = [
          {
            name = "main"
            layout = {
              shardsCount   = 1
              replicasCount = 1
            }
          }
        ]
      }
      defaults = {
        templates = {
          podTemplate     = "clickhouse-pod"
          serviceTemplate = "clickhouse-service"
        }
      }
      templates = {
        podTemplates = [
          {
            name = "clickhouse-pod"
            spec = {
              containers = [
                {
                  name            = "clickhouse"
                  image           = "clickhouse/clickhouse-server:25.7.8"
                  imagePullPolicy = "IfNotPresent"
                  resources = {
                    limits = {
                      cpu    = "1000m"
                      memory = "1Gi"
                    }
                    requests = {
                      cpu    = "200m"
                      memory = "256Mi"
                    }
                  }
                  volumeMounts = [
                    {
                      name      = "clickhouse-data"
                      mountPath = "/var/lib/clickhouse"
                    }
                  ]
                }
              ]
            }
          }
        ]
        volumeClaimTemplates = [
          {
            name = "clickhouse-data"
            spec = {
              storageClassName = "local-path-retain"
              accessModes      = ["ReadWriteOnce"]
              resources = {
                requests = {
                  storage = "10Gi"
                }
              }
            }
          }
        ]
        serviceTemplates = [
          {
            name = "clickhouse-service"
            metadata = {
              name = "clickhouse"
            }
            spec = {
              type = "ClusterIP"
              ports = [
                {
                  name = "http"
                  port = 8123
                },
                {
                  name = "tcp"
                  port = 9000
                }
              ]
            }
          }
        ]
      }
    }
  })

  depends_on = [
    time_sleep.wait_for_clickhouse_secret,
    time_sleep.wait_for_clickhouse_crd
  ]
}

# =============================================================================
# SigNoz ClickHouse User & Databases (moved from Platform)
# =============================================================================

# Wait for ClickHouse to be ready before creating users
resource "time_sleep" "wait_for_clickhouse" {
  create_duration = "30s"
  depends_on      = [kubectl_manifest.clickhouse_installation]
}

# SigNoz password
resource "random_password" "signoz_clickhouse" {
  length  = 24
  special = false
}

# Store SigNoz credentials in Vault for L4 to consume
resource "vault_kv_secret_v2" "signoz" {
  mount               = data.terraform_remote_state.platform.outputs.vault_kv_mount
  name                = "signoz"
  delete_all_versions = true

  data_json = jsonencode({
    username = "signoz"
    password = random_password.signoz_clickhouse.result
    host     = "clickhouse.${local.namespace_name}.svc.cluster.local"
    port     = "9000"
    database = "signoz_traces"
  })

  depends_on = [time_sleep.wait_for_clickhouse]
}

# Create SigNoz User in ClickHouse
resource "clickhousedbops_user" "signoz" {
  name                            = "signoz"
  password_sha256_hash_wo         = sha256(random_password.signoz_clickhouse.result)
  password_sha256_hash_wo_version = 1

  depends_on = [time_sleep.wait_for_clickhouse]
}

# Create SigNoz Databases
resource "clickhousedbops_database" "signoz_traces" {
  name       = "signoz_traces"
  depends_on = [time_sleep.wait_for_clickhouse]
}

resource "clickhousedbops_database" "signoz_metrics" {
  name       = "signoz_metrics"
  depends_on = [time_sleep.wait_for_clickhouse]
}

resource "clickhousedbops_database" "signoz_logs" {
  name       = "signoz_logs"
  depends_on = [time_sleep.wait_for_clickhouse]
}

# =============================================================================
# Outputs
# =============================================================================

output "clickhouse_host" {
  value       = "clickhouse.${local.namespace_name}.svc.cluster.local"
  description = "ClickHouse K8s service DNS for L4 applications"
}

output "clickhouse_http_port" {
  value       = "8123"
  description = "ClickHouse HTTP interface port"
}

output "clickhouse_native_port" {
  value       = "9000"
  description = "ClickHouse native protocol port"
}

output "clickhouse_vault_path" {
  value       = "${data.terraform_remote_state.platform.outputs.vault_kv_mount}/data/${data.terraform_remote_state.platform.outputs.vault_db_secrets["clickhouse"]}"
  description = "Vault KV path for ClickHouse credentials"
}

output "signoz_vault_path" {
  value       = "${data.terraform_remote_state.platform.outputs.vault_kv_mount}/data/signoz"
  description = "Vault KV path for SigNoz ClickHouse credentials"
}



# =============================================================================
# OpenPanel ClickHouse User & Database (Event Storage)
# Purpose: High-volume event analytics for OpenPanel
# Pattern: Similar to SigNoz (static credentials)
# =============================================================================

# Generate password for OpenPanel ClickHouse user
resource "random_password" "openpanel_clickhouse" {
  length  = 24
  special = false
}

# Create OpenPanel User in ClickHouse
resource "clickhousedbops_user" "openpanel" {
  name                            = "openpanel"
  password_sha256_hash_wo         = sha256(random_password.openpanel_clickhouse.result)
  password_sha256_hash_wo_version = 1

  depends_on = [time_sleep.wait_for_clickhouse]
}

# Create OpenPanel Events Database
resource "clickhousedbops_database" "openpanel_events" {
  name       = "openpanel_events"
  depends_on = [time_sleep.wait_for_clickhouse]
}

# Note: Privileges are automatically granted to user on database creation
# No need for explicit grant_privilege resource (same pattern as SigNoz)
# Verify with: kubectl exec -n data-staging clickhouse-0 -- clickhouse-client --query "SHOW GRANTS FOR openpanel"

# Output for L4 consumption (credentials already in Vault via 1.postgres.tf)
output "openpanel_clickhouse_database" {
  value       = clickhousedbops_database.openpanel_events.name
  description = "OpenPanel ClickHouse events database name"
}
