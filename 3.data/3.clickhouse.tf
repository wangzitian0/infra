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
# ClickHouse via Bitnami Helm chart
# =============================================================================

resource "helm_release" "clickhouse" {
  name             = "clickhouse"
  namespace        = local.namespace_name # Per-env: data-staging, data-prod
  repository       = "oci://registry-1.docker.io/bitnamicharts"
  chart            = "clickhouse"
  version          = "9.4.4" # Upgraded from 6.2.17 to resolve image availability issues
  create_namespace = false
  timeout          = 300 # Consistent with PR #170 standard (was 600s)
  wait             = true
  wait_for_jobs    = true

  lifecycle {
    # Temporarily disabled to allow re-deployment after failed release
    # TODO: Re-enable after initial deployment succeeds
    prevent_destroy = false

    precondition {
      condition     = can(data.vault_kv_secret_v2.clickhouse.data["password"]) && length(data.vault_kv_secret_v2.clickhouse.data["password"]) >= 16
      error_message = "ClickHouse password must be available in Vault KV and at least 16 characters."
    }
  }

  values = [
    yamlencode({
      # Pin both main and keeper images to avoid ImagePullBackOff
      image = {
        tag        = "24.8.5-debian-12" # Pin to valid rolling tag
        pullPolicy = "IfNotPresent"
      }
      auth = {
        username = "default"
        password = data.vault_kv_secret_v2.clickhouse.data["password"]
      }
      shards       = 1 # Single VPS MVP: single shard (can scale later)
      replicaCount = 1 # Single VPS MVP: no replication (can scale later)
      zookeeper = {
        enabled = false # Disable external ZooKeeper
      }
      keeper = {
        enabled = true # Enable bundled ClickHouse Keeper
        image = {
          # Bitnami removed versioned tags after Aug 2025, only 'latest' available
          tag        = "latest"
          pullPolicy = "IfNotPresent"
        }
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
      # Note: Custom profiles/quotas removed for MVP stability
      # TODO: Add custom configs via usersFiles if needed per Bitnami docs
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
