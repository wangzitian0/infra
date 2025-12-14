# L3 ClickHouse
#
# Purpose: OLAP analytics database for L4 applications
# Password: Read from Vault KV at secret/data/clickhouse (generated in L2)
# Pattern: Bitnami Helm chart
# Namespace: per-env (data-staging, data-prod)
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
# Health Check: Vault Readiness
# =============================================================================

data "external" "vault_ready_clickhouse" {
  program = ["sh", "-c", "nc -z vault.platform.svc 8200 && echo '{\"ok\":\"true\"}' || echo '{\"ok\":\"false\"}' "]
}

# =============================================================================
# ClickHouse via Bitnami Helm chart
# =============================================================================

resource "helm_release" "clickhouse" {
  name             = "clickhouse"
  namespace        = local.namespace_name  # Per-env: data-staging, data-prod
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "clickhouse"
  version          = "6.2.17"
  create_namespace = false
  timeout          = 300  # Consistent with PR #170 standard (was 600s)
  wait             = true
  wait_for_jobs    = true

  lifecycle {
    prevent_destroy = true  # Prevent accidental data loss

    precondition {
      condition     = data.external.vault_ready_clickhouse.result.ok == "true"
      error_message = "Vault not ready - ClickHouse needs Vault for password retrieval"
    }
  }

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
      # Wait for Vault before starting
      initContainers = [
        {
          name    = "wait-for-vault"
          image   = "busybox:1.36"
          command = ["sh", "-c", "until nc -z vault.platform.svc 8200; do echo 'Waiting for Vault...'; sleep 2; done; echo 'Vault is ready'"]
        }
      ]
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
      # Resource limits to prevent runaway queries
      extraOverrides = <<-EOT
        <profiles>
          <default>
            <max_memory_usage>800000000</max_memory_usage>
            <max_execution_time>300</max_execution_time>
            <max_concurrent_queries>10</max_concurrent_queries>
          </default>
        </profiles>
        <quotas>
          <default>
            <interval>
              <duration>3600</duration>
              <queries>1000</queries>
            </interval>
          </default>
        </quotas>
      EOT
    })
  ]
}

# =============================================================================
# Outputs
# =============================================================================

output "clickhouse_host" {
  value       = "${helm_release.clickhouse.name}.${local.namespace_name}.svc.cluster.local"
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
