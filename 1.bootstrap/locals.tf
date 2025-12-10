locals {
  api_endpoint = coalesce(var.api_endpoint, var.vps_host)

  internal_domain = var.internal_domain != "" ? var.internal_domain : var.base_domain

  # Resolve internal zone:
  # 1) respect explicit internal_zone_id
  # 2) if internal domain differs and no zone provided, look up Cloudflare zone by name
  # 3) fallback to base zone
  internal_zone_id = var.internal_zone_id != "" ? var.internal_zone_id : (
    local.internal_domain != var.base_domain
    ? try(data.cloudflare_zones.internal[0].zones[0].id, var.cloudflare_zone_id)
    : var.cloudflare_zone_id
  )

  disable_flags = length(var.disable_components) > 0 ? join(" ", [
    for c in var.disable_components : "--disable ${c}"
  ]) : ""

  kubeconfig_path = "${path.module}/output/${var.cluster_name}-kubeconfig.yaml"

  # Calculate domain prefix (e.g., "x-staging." or "")
  # If env_prefix is empty (prod), no prefix.
  # If env_prefix is set, append dot.

  # Domain map (i-* for infra, x-* via env_prefix for env traffic)
  domains = {
    # Infra (dedicated internal domain)
    atlantis  = "atlantis.${local.internal_domain}"
    k3s       = "k3s.${local.internal_domain}"
    dashboard = "kdashboard.${local.internal_domain}"
    vault     = "secrets.${local.internal_domain}"

    # Platform services
    kubero_ui      = "kcloud.${local.internal_domain}"
    kubero_backend = "kapi.${local.internal_domain}"
    signoz         = "signoz.${local.internal_domain}"
    posthog        = "posthog.${local.internal_domain}"

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

  # Format dnsNames as indented YAML list items for Certificate resources
  base_cert_domains_yaml     = join("\n", [for d in local.base_cert_domains : "    - \"${d}\""])
  internal_cert_domains_yaml = join("\n", [for d in local.internal_cert_domains : "    - \"${d}\""])
}

data "cloudflare_zones" "internal" {
  count = local.internal_domain != var.base_domain && var.internal_zone_id == "" ? 1 : 0
  filter {
    name   = local.internal_domain
    status = "active"
  }
}

