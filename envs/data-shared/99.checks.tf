# =============================================================================
# Data Services Health Validation
# =============================================================================
# Summary output for all Data service deployment status.
# Individual postconditions are in their respective files.

output "data_health_status" {
  value = {
    postgres   = "cnpg-cluster" # Using kubectl_manifest.postgresql_cluster
    redis      = helm_release.redis.status
    clickhouse = helm_release.clickhouse.status
    arangodb   = helm_release.arangodb_operator.status
  }
  description = "Data services deployment status summary"
}

output "data_namespace" {
  value       = local.namespace_name
  description = "Data namespace for current workspace"
}
