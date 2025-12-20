# ============================================================
# SigNoz Observability Stack
# Deploys metrics, traces, and logs platform to L4
#
# Architecture:
# - L4 singleton control plane
# - Uses L3 ClickHouse (data-staging namespace)
# - Reads ClickHouse password from Vault
# ============================================================

# ============================================================
# Vault Data Source - Read ClickHouse credentials
# ============================================================
data "vault_kv_secret_v2" "clickhouse" {
  mount = var.vault_kv_mount
  name  = "clickhouse"

  lifecycle {
    postcondition {
      condition     = can(self.data["password"]) && length(self.data["password"]) >= 16
      error_message = "ClickHouse password not found in Vault or too short. Ensure L2/L3 applied."
    }
  }
}

# ============================================================
# Observability Namespace
# ============================================================
resource "kubernetes_namespace" "observability" {
  metadata {
    name = "observability"
    labels = {
      "layer" = "L4"
    }
  }
}

# ============================================================
# SigNoz Helm Release
# Chart: https://charts.signoz.io
# ============================================================
resource "helm_release" "signoz" {
  name       = "signoz"
  namespace  = kubernetes_namespace.observability.metadata[0].name
  repository = "https://charts.signoz.io"
  chart      = "signoz"
  version    = "0.52.0" # Pin version for reproducibility

  wait    = true
  timeout = 600 # 10 minutes

  values = [yamlencode({
    # Disable bundled ClickHouse - use L3 external ClickHouse
    clickhouse = {
      enabled = false
    }

    # Connect to L3 ClickHouse (data-staging namespace)
    externalClickhouse = {
      host     = "clickhouse.data-staging.svc.cluster.local"
      httpPort = 8123
      tcpPort  = 9000
      user     = "default"
      password = data.vault_kv_secret_v2.clickhouse.data["password"]
      # SigNoz will create its own database within ClickHouse
      database = "signoz_traces"
    }

    # Frontend configuration
    frontend = {
      ingress = {
        enabled   = true
        className = "traefik"
        hosts = [{
          host = "signoz.${var.internal_domain}"
          paths = [{
            path     = "/"
            pathType = "Prefix"
            port     = 3301 # SigNoz frontend port
          }]
        }]
        tls = [{
          secretName = "wildcard-tls-internal"
          hosts      = ["signoz.${var.internal_domain}"]
        }]
      }
    }

    # Query service - lighter resources since ClickHouse is external
    queryService = {
      resources = {
        requests = { cpu = "100m", memory = "256Mi" }
        limits   = { cpu = "500m", memory = "512Mi" }
      }
    }

    # OTel Collector
    otelCollector = {
      resources = {
        requests = { cpu = "100m", memory = "256Mi" }
        limits   = { cpu = "500m", memory = "512Mi" }
      }
    }
  })]

  depends_on = [kubernetes_namespace.observability]
}

# ============================================================
# Outputs
# ============================================================
output "signoz_url" {
  description = "SigNoz UI URL"
  value       = "https://signoz.${var.internal_domain}"
}

output "signoz_otel_endpoint" {
  description = "OpenTelemetry collector endpoint for applications"
  value       = "signoz-otel-collector.observability.svc.cluster.local:4317"
}
