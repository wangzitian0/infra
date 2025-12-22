# L3 ClickHouse
#
# Purpose: OLAP analytics database for L4 applications
#
# Architecture (after refactor - Issue #336):
# - L3 generates password locally
# - L3 stores password in Vault KV
# - L3 manages ClickHouse users via clickhousedbops provider
# - L4 reads credentials from Vault KV
#
# Pattern: Bitnami Helm chart
# Namespace: per-env (data-staging, data-prod)
#
# Scalability:
# Current: Single node (shards=1, replicaCount=1, zookeeper=disabled)
# Future: Enable sharding/replication (requires ZooKeeper)

# =============================================================================
# Password Generation (generated in L3, stored in Vault)
# =============================================================================

resource "random_password" "clickhouse" {
  length  = 32
  special = false
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

    postcondition {
      condition     = self.status == "deployed"
      error_message = "ClickHouse Helm release failed to deploy. Check pod logs and events."
    }
  }

  values = [
    yamlencode({
      # Bitnami moved all images to bitnamilegacy repo (bitnami/ is empty)
      image = {
        registry   = "docker.io"
        repository = "bitnamilegacy/clickhouse"
        tag        = "25.7.5-debian-12-r0" # Matches Chart 9.4.4 default
        pullPolicy = "IfNotPresent"
      }
      auth = {
        username = "default"
        password = random_password.clickhouse.result
      }
      shards       = 1 # Single VPS MVP: single shard (can scale later)
      replicaCount = 1 # Single VPS MVP: no replication (can scale later)
      zookeeper = {
        enabled = false # Disable external ZooKeeper
      }
      keeper = {
        enabled = false # Disabled: Single node MVP doesn't need Keeper (saves 4500m CPU)
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

  depends_on = [kubernetes_namespace.data]
}

# =============================================================================
# Vault KV Storage
# =============================================================================

resource "vault_kv_secret_v2" "clickhouse" {
  mount               = data.terraform_remote_state.l2_platform.outputs.vault_kv_mount
  name                = data.terraform_remote_state.l2_platform.outputs.vault_db_secrets["clickhouse"]
  delete_all_versions = true

  data_json = jsonencode({
    username = "default"
    password = random_password.clickhouse.result
    host     = "${helm_release.clickhouse.name}.${local.namespace_name}.svc.cluster.local"
    port     = "9000"
    database = "default"
  })

  depends_on = [helm_release.clickhouse]
}

# =============================================================================
# SigNoz ClickHouse User & Databases (moved from L2)
# =============================================================================

# Wait for ClickHouse to be ready before creating users
resource "time_sleep" "wait_for_clickhouse" {
  create_duration = "30s"
  depends_on      = [helm_release.clickhouse]
}

# SigNoz password
resource "random_password" "signoz_clickhouse" {
  length  = 24
  special = false
}

# Store SigNoz credentials in Vault for L4 to consume
resource "vault_kv_secret_v2" "signoz" {
  mount               = data.terraform_remote_state.l2_platform.outputs.vault_kv_mount
  name                = "signoz"
  delete_all_versions = true

  data_json = jsonencode({
    username = "signoz"
    password = random_password.signoz_clickhouse.result
    host     = "${helm_release.clickhouse.name}.${local.namespace_name}.svc.cluster.local"
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
  value       = "${data.terraform_remote_state.l2_platform.outputs.vault_kv_mount}/data/${data.terraform_remote_state.l2_platform.outputs.vault_db_secrets["clickhouse"]}"
  description = "Vault KV path for ClickHouse credentials"
}

output "signoz_vault_path" {
  value       = "${data.terraform_remote_state.l2_platform.outputs.vault_kv_mount}/data/signoz"
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
