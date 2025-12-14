# L3 ClickHouse
#
# Purpose: OLAP analytics database for L4 applications
# Password: Read from Vault KV at secret/data/clickhouse (generated in L2)
# Pattern: Bitnami Helm chart
# Namespace: data (shared with PostgreSQL)
#
# Architecture:
# L2 generates password → stores in Vault KV
# L3 reads password from Vault KV → deploys ClickHouse
#
# Scalability:
# Current: Single node (shards=1, replicaCount=1, zookeeper=disabled)
# Future: Enable sharding/replication (requires ZooKeeper, see implementation_plan.md)

# =============================================================================
# Read Password from Vault (generated and stored by L2)
# Requires: TF_VAR_vault_root_token set in Atlantis Pod env
# =============================================================================

data "vault_kv_secret_v2" "clickhouse" {
  mount = "secret"
  name  = "data/clickhouse"
}

# =============================================================================
# ClickHouse via Bitnami Helm chart
# =============================================================================

resource "helm_release" "clickhouse" {
  name             = "clickhouse"
  namespace        = kubernetes_namespace.data.metadata[0].name
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "clickhouse"
  version          = "6.2.17"
  create_namespace = false
  timeout          = 600
  wait             = true
  wait_for_jobs    = true

  values = [
    yamlencode({
      # Bitnami deletes old tags; use latest + IfNotPresent to reduce drift
      image = {
        tag        = "latest"
        pullPolicy = "IfNotPresent"
      }
      auth = {
        username = "default"
        password = data.vault_kv_secret_v2.clickhouse.data["password"]
      }
      shards       = 1     # Single VPS MVP: single shard (can scale later)
      replicaCount = 1     # Single VPS MVP: no replication (can scale later)
      zookeeper = {
        enabled = false    # Disable ZooKeeper for single-node setup
      }
      persistence = {
        enabled      = true
        storageClass = "local-path-retain"
        size         = "10Gi"
      }
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
    })
  ]
}

# =============================================================================
# Outputs
# =============================================================================

output "clickhouse_host" {
  value       = "clickhouse.data.svc.cluster.local"
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
  value       = "secret/data/clickhouse"
  description = "Vault KV path for ClickHouse credentials"
}
