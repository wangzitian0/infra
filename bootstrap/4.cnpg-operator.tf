# CloudNativePG Operator
# Professional PostgreSQL management for Kubernetes
# https://cloudnative-pg.io
#
# Features:
# - Automatic HA / Failover
# - Native PITR backup/restore
# - Zero-downtime rolling upgrades
# - Prometheus-native monitoring

# Import existing helm release to sync state if already deployed
# Per ops.standards.md Rule 4: sync state via import, not ignore_changes
# This handles cases where chart exists but isn't in Terraform state (e.g., after state rm)
import {
  to = helm_release.cnpg_operator
  id = "cnpg-system/cnpg"
}

resource "helm_release" "cnpg_operator" {
  name             = "cnpg"
  namespace        = "cnpg-system"
  repository       = "https://cloudnative-pg.github.io/charts"
  chart            = "cloudnative-pg"
  version          = "0.22.0"
  create_namespace = true
  wait             = true
  timeout          = 300

  values = [yamlencode({
    monitoring = {
      podMonitorEnabled = false # Enable when Prometheus is ready
    }
  })]

  lifecycle {
    postcondition {
      condition     = self.status == "deployed"
      error_message = "CNPG operator Helm release failed to deploy."
    }
  }
}

# Output for other layers to verify operator is ready
output "cnpg_operator_ready" {
  value       = helm_release.cnpg_operator.status == "deployed"
  description = "CloudNativePG operator deployment status"
}
