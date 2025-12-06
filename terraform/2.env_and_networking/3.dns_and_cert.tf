# L2.3: DNS & Certificate Management (Cloudflare + CertManager)

# 1. Namespaces
# Define "cert-manager" namespace explicitly so we can put secrets in it
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

# 2. Secrets
# Cloudflare API Token for DNS-01 challenge
resource "kubernetes_secret" "cloudflare_api_token" {
  metadata {
    name      = "cloudflare-api-token-secret"
    namespace = kubernetes_namespace.cert_manager.metadata[0].name
  }
  data = {
    api-token = var.cloudflare_api_token
  }
}

# 3. Cert Manager Helm Release
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.13.3"
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [kubernetes_namespace.cert_manager]
}

# 4. ClusterIssuer (Let's Encrypt Production)
resource "kubernetes_manifest" "cluster_issuer_letsencrypt_prod" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        email  = "admin@${var.base_domain}"
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [
          {
            dns01 = {
              cloudflare = {
                apiTokenSecretRef = {
                  name = "cloudflare-api-token-secret"
                  key  = "api-token"
                }
              }
            }
          }
        ]
      }
    }
  }
  depends_on = [helm_release.cert_manager, kubernetes_secret.cloudflare_api_token]
}

# 5. Cloudflare DNS Record
# Points 'atlantis' subdomain to the VPS IP (Ingress Controller)
resource "cloudflare_record" "atlantis" {
  zone_id = var.cloudflare_zone_id
  name    = "atlantis"
  value   = var.vps_host
  type    = "A"
  proxied = false # Use DNS-only initially to ensure Cert Manager validation works smoothly
}
