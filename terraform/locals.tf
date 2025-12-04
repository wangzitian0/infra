locals {
  # k3s
  api_endpoint      = coalesce(var.api_endpoint, var.vps_host)
  disable_flags     = length(var.disable_components) > 0 ? join(" ", [for c in var.disable_components : "--disable ${c}"]) : ""
  kubeconfig_path   = "${path.module}/output/${var.cluster_name}-kubeconfig.yaml"

  # Domain helpers
  full_domain_prefix = var.domain_prefix != "" ? "${var.domain_prefix}." : ""

  # Ingress domains for services
  domains = {
    infisical = "cloud-${local.full_domain_prefix}${var.base_domain}"
    kubero    = "api-${local.full_domain_prefix}${var.base_domain}"
    signoz    = "signoz-${local.full_domain_prefix}${var.base_domain}"
    posthog   = "posthog-${local.full_domain_prefix}${var.base_domain}"
    app       = "${local.full_domain_prefix}${var.base_domain}"
  }

  # Namespaces
  namespaces = {
    iac            = "iac"
    data           = "data"
    kubero         = "kubero"
    apps           = "apps"
    observability  = "observability"
    ingestion      = "ingestion"
  }
}
