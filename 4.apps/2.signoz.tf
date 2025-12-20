# ============================================================
# SigNoz Observability Stack
# Deploys metrics, traces, and logs platform to L4
#
# Architecture:
# - L4 singleton control plane
# - Uses L3 ClickHouse (data-staging namespace)
# - Dedicated signoz user with limited DB permissions
# ============================================================

# NOTE: SigNoz credentials are currently hardcoded (signoz user created manually in ClickHouse)
# TODO: Move signoz password to Vault and use data source in follow-up PR

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
    # Using dedicated signoz user with limited permissions
    # TODO: Move signoz password to Vault (L2) in follow-up PR
    externalClickhouse = {
      host     = "clickhouse.data-staging.svc.cluster.local"
      httpPort = 8123
      tcpPort  = 9000
      user     = "signoz"
      password = "signoz_secure_password_2024"
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
