locals {
  api_endpoint = coalesce(var.api_endpoint, var.vps_host)

  internal_domain  = var.internal_domain != "" ? var.internal_domain : var.base_domain
  internal_zone_id = var.internal_zone_id != "" ? var.internal_zone_id : var.cloudflare_zone_id

  disable_flags = length(var.disable_components) > 0 ? join(" ", [
    for c in var.disable_components : "--disable ${c}"
  ]) : ""

  kubeconfig_path = "${path.module}/output/${var.cluster_name}-kubeconfig.yaml"

  # Calculate domain prefix (e.g., "x-staging." or "")
  # If env_prefix is empty (prod), no prefix.
  # If env_prefix is set, append dot.

  # Domain map (i-* for infra, x-* via env_prefix for env traffic)
  domains = {
    # Infra (DNS-only / grey cloud)
    atlantis  = "i-atlantis.${local.internal_domain}"
    k3s       = "i-k3s.${local.internal_domain}"
    dashboard = "i-kdashboard.${local.internal_domain}"
    vault     = "i-secrets.${local.internal_domain}"

    # Platform services
    kubero_ui      = "i-kcloud.${local.internal_domain}"
    kubero_backend = "i-kapi.${local.internal_domain}"
    signoz         = "i-signoz.${local.internal_domain}"
    posthog        = "i-posthog.${local.internal_domain}"

    # Env/External (proxied / orange cloud)
    frontend = "${var.env_prefix}.${var.base_domain}"
    backend  = "${var.env_prefix}-api.${var.base_domain}"
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

  base_cert_domains = distinct(compact([
    var.base_domain,
    "*.${var.base_domain}"
  ]))

  internal_cert_domains = distinct(compact([
    local.internal_domain,
    "*.${local.internal_domain}"
  ]))

  base_cert_domains_yaml     = join("\n        ", [for d in local.base_cert_domains : "- \"${d}\""])
  internal_cert_domains_yaml = join("\n        ", [for d in local.internal_cert_domains : "- \"${d}\""])
}
