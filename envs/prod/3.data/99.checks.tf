# =============================================================================
# L3 Data Services Health Validation
# =============================================================================
# Summary output for all L3 data service deployment status.
# Individual postconditions are in their respective files.

output "l3_health_status" {
  value = {
    postgres   = helm_release.postgresql.status
    redis      = helm_release.redis.status
    clickhouse = helm_release.clickhouse.status
    arangodb   = helm_release.arangodb_operator.status
  }
  description = "L3 data services deployment status summary"
}

output "l3_namespace" {
  value       = local.namespace_name
  description = "L3 data namespace for current workspace"
}
