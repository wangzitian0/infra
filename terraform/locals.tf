locals {
  api_endpoint = coalesce(var.api_endpoint, var.vps_host)

  disable_flags = length(var.disable_components) > 0 ? join(" ", [
    for c in var.disable_components : "--disable ${c}"
  ]) : ""

  kubeconfig_path = "${path.module}/output/${var.cluster_name}-kubeconfig.yaml"

  full_domain_prefix = var.domain_prefix != "" ? "${var.domain_prefix}." : ""

  domains = {
    app       = "${local.full_domain_prefix}${var.base_domain}"
    infisical = "cloud-${local.full_domain_prefix}${var.base_domain}"
    kubero    = "api-${local.full_domain_prefix}${var.base_domain}"
    posthog   = "posthog-${local.full_domain_prefix}${var.base_domain}"
    signoz    = "signoz-${local.full_domain_prefix}${var.base_domain}"
  }

  namespaces = {
    nodep         = "nodep"
    security      = "security"
    apps          = "apps"
    data          = "data"
    ingestion     = "ingestion"
    kubero        = "kubero"
    observability = "observability"
  }
}
