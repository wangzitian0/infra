locals {
  api_endpoint = coalesce(var.api_endpoint, var.vps_host)

  disable_flags = length(var.disable_components) > 0 ? join(" ", [
    for c in var.disable_components : "--disable ${c}"
  ]) : ""

  kubeconfig_path = "${path.module}/output/${var.cluster_name}-kubeconfig.yaml"

  # Calculate domain prefix (e.g., "x-staging." or "")
  # If env_prefix is empty (prod), no prefix.
  # If env_prefix is set, append dot.

  # Update per network.md (i- prefix for internal, x- prefix for env)
  # Actually, network.md defines full patterns. We should just map them here for outputs/convenience.

  domains = {
    # Global/Internal
    atlantis = "i-atlantis.${var.base_domain}"
    k3s      = "i-k3s.${var.base_domain}"

    # Env/Internal-ish (Fixed names per User Request)
    kubero_ui      = "i-kcloud.${var.base_domain}"
    kubero_backend = "i-kapi.${var.base_domain}"
    infisical      = "i-secrets.${var.base_domain}"
    signoz         = "i-signoz.${var.base_domain}"

    # Env/Variable (Pattern B)
    posthog  = "${var.env_prefix}-posthog.${var.base_domain}"
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
}
