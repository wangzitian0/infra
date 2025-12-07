# Phase 1.4: Kubero (GitOps PaaS Controller)
# Namespace: kubero
# Access: Ingress via i-kcloud.{base_domain} (UI) and i-kapi.{base_domain} (API)
#
# TEMPORARILY DISABLED: charts.kubero.dev DNS is not resolving
# TODO: Re-enable once Kubero chart repo is accessible or find alternative

# Create namespace for Kubero (kept for future use)
resource "kubernetes_namespace" "kubero" {
  metadata {
    name = "kubero"
  }
}

# Generate secure session secret for Kubero (kept for future use)
resource "random_id" "kubero_session_secret" {
  byte_length = 32
}

# Deploy Kubero Operator using Helm
# DISABLED: charts.kubero.dev is currently unreachable
# resource "helm_release" "kubero" {
#   name       = "kubero"
#   repository = "https://charts.kubero.dev/"
#   chart      = "kubero-operator"
#   version    = "0.2.2"
#   namespace  = kubernetes_namespace.kubero.metadata[0].name
#
#   values = [
#     yamlencode({
#       kuberoUi = {
#         enabled = true
#         image = { tag = "v2.4.0" }
#         ingress = {
#           enabled   = true
#           className = "nginx"
#           annotations = { "cert-manager.io/cluster-issuer" = "letsencrypt-prod" }
#           hosts = [{ host = "i-kcloud.${var.base_domain}", paths = [{ path = "/", pathType = "Prefix" }] }]
#           tls = [{ secretName = "kubero-ui-tls", hosts = ["i-kcloud.${var.base_domain}"] }]
#         }
#         config = { kubero = { sessionKey = random_id.kubero_session_secret.hex } }
#       }
#       kuberoApi = {
#         ingress = {
#           enabled   = true
#           className = "nginx"
#           annotations = { "cert-manager.io/cluster-issuer" = "letsencrypt-prod" }
#           hosts = [{ host = "i-kapi.${var.base_domain}", paths = [{ path = "/", pathType = "Prefix" }] }]
#           tls = [{ secretName = "kubero-api-tls", hosts = ["i-kapi.${var.base_domain}"] }]
#         }
#       }
#       resources = {
#         requests = { cpu = "100m", memory = "128Mi" }
#         limits = { cpu = "500m", memory = "512Mi" }
#       }
#     })
#   ]
#   depends_on = [kubernetes_namespace.kubero]
# }

# Outputs (placeholder URLs until Kubero is deployed)
output "kubero_ui_url" {
  value       = "https://i-kcloud.${var.base_domain}"
  description = "Kubero UI URL (not deployed yet - charts.kubero.dev unreachable)"
}

output "kubero_api_url" {
  value       = "https://i-kapi.${var.base_domain}"
  description = "Kubero API URL (not deployed yet - charts.kubero.dev unreachable)"
}
