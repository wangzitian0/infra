# L2.3: DNS & Certificate Management (Cloudflare + CertManager)

locals {
  infra_dns_records = {
    atlantis   = true  # HTTPS via proxy
    secrets    = false # Vault - DNS only (avoid Cloudflare caching issues with OIDC)
    kdashboard = true  # HTTPS via proxy
    kcloud     = true  # HTTPS via proxy
    kapi       = true  # HTTPS via proxy
    signoz     = true  # HTTPS via proxy
    openpanel  = true  # HTTPS via proxy
    home       = true  # Homer Portal - HTTPS via proxy
    sso        = false # SSO (Casdoor) - DNS only (avoid Cloudflare caching/WAF issues)
    auth       = true  # OAuth2-Proxy callback for Portal SSO Gate
    k3s        = false # API on 6443, must stay DNS-only
  }

  # When internal_domain uses a different zone, keep the wildcard for convenience
  internal_zone_is_distinct = local.internal_zone_id != var.cloudflare_zone_id || local.internal_domain != var.base_domain
}

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
  timeout    = 300
  wait       = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [kubernetes_namespace.cert_manager]
}

# 4. ClusterIssuer (Let's Encrypt Production)
# Use kubectl_manifest to avoid plan-time CRD validation failures.
resource "kubectl_manifest" "cluster_issuer_letsencrypt_prod" {
  yaml_body = yamlencode({
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
                  name = kubernetes_secret.cloudflare_api_token.metadata[0].name
                  key  = "api-token"
                }
              }
            }
          }
        ]
      }
    }
  })

  server_side_apply = true

  depends_on = [helm_release.cert_manager, kubernetes_secret.cloudflare_api_token]
}

# 5. Wildcard Certificate (covers *.domain and domain)
# Using DNS-01 challenge via Cloudflare for wildcard cert
resource "kubectl_manifest" "wildcard_certificate_public" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "wildcard-tls-public"
      namespace = kubernetes_namespace.cert_manager.metadata[0].name
    }
    spec = {
      secretName = "wildcard-tls-public"
      issuerRef = {
        name = "letsencrypt-prod"
        kind = "ClusterIssuer"
      }
      dnsNames = local.base_cert_domains
    }
  })

  server_side_apply = true

  depends_on = [kubectl_manifest.cluster_issuer_letsencrypt_prod]
}

resource "kubectl_manifest" "wildcard_certificate_internal" {
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "wildcard-tls-internal"
      namespace = kubernetes_namespace.cert_manager.metadata[0].name
    }
    spec = {
      secretName = "wildcard-tls-internal"
      issuerRef = {
        name = "letsencrypt-prod"
        kind = "ClusterIssuer"
      }
      dnsNames = local.internal_cert_domains
    }
  })

  server_side_apply = true

  depends_on = [kubectl_manifest.cluster_issuer_letsencrypt_prod]
}

# 6. Cloudflare DNS Records
# =============================================================================
# Architecture: 
# - Infra on internal_domain (no prefix): per-record proxy (443 services proxied, k3s DNS-only)
# - BASE_DOMAIN (public/x-*): Proxied (orange cloud) - CDN & DDoS protection
# - Wildcard_internal: proxied wildcard when internal_domain uses a separate zone (overridden by explicit records)
# - Wildcard_public: proxied wildcard for public; explicit internal records override when sharing the same zone
# =============================================================================

# Wildcard: proxied for internal services when using a separate internal zone
# Explicit records below override per-service proxy settings
resource "cloudflare_record" "wildcard_internal" {
  count           = local.internal_zone_is_distinct ? 1 : 0
  zone_id         = local.internal_zone_id
  name            = "*"
  content         = var.vps_host
  type            = "A"
  proxied         = true
  allow_overwrite = true
}

# Explicit infra records with per-service proxy settings (k3s stays DNS-only)
resource "cloudflare_record" "infra_records" {
  for_each        = local.infra_dns_records
  zone_id         = local.internal_zone_id
  name            = each.key
  content         = var.vps_host
  type            = "A"
  proxied         = each.value
  allow_overwrite = true
}

resource "cloudflare_record" "wildcard_public" {
  zone_id         = var.cloudflare_zone_id
  name            = "*"
  content         = var.vps_host
  type            = "A"
  proxied         = true
  allow_overwrite = true
}

# Root domain: proxied for public access
resource "cloudflare_record" "root" {
  zone_id         = var.cloudflare_zone_id
  name            = "@"
  content         = var.vps_host
  type            = "A"
  proxied         = true
  allow_overwrite = true
}

# =============================================================================
# External Environment DNS Records (x-* pattern, Orange Cloud / Proxied)
# These provide CDN caching and DDoS protection for user-facing services
# =============================================================================

# x-staging: Staging environment services (x-staging-api, x-staging-app, etc.)
resource "cloudflare_record" "x_staging" {
  zone_id         = var.cloudflare_zone_id
  name            = "x-staging"
  content         = var.vps_host
  type            = "A"
  proxied         = true
  allow_overwrite = true
}

# Production uses root domain directly: api.base.com, base.com
# No x-prod prefix needed

# Note: x-test* records for ephemeral environments are CI-managed:
# - x-testpr-123-api, x-testpr-456-app (PR previews)
# - x-testcommit-abc123-api (commit previews)

# =============================================================================
# 7. Post-Apply Validation (DNS + Cert + Atlantis Health)
# =============================================================================

# Validate DNS resolution for Atlantis host
resource "time_sleep" "wait_for_atlantis_dns" {
  create_duration = "60s"
  triggers = {
    host   = local.domains.atlantis
    vps_ip = var.vps_host
  }
  depends_on = [cloudflare_record.infra_records]
}

data "dns_a_record_set" "atlantis" {
  host       = local.domains.atlantis
  depends_on = [time_sleep.wait_for_atlantis_dns]

  lifecycle {
    postcondition {
      condition     = length(self.addrs) > 0
      error_message = "DNS resolution failed for ${local.domains.atlantis}."
    }
  }
}

# Validate HTTPS certificate + Atlantis health
resource "time_sleep" "wait_for_atlantis_https" {
  create_duration = "120s"
  triggers = {
    # Use chart version instead of revision (revision changes during apply, causing TF error)
    atlantis_version = helm_release.atlantis.version
    domain           = local.domains.atlantis
  }
  depends_on = [
    kubectl_manifest.wildcard_certificate_internal,
    helm_release.atlantis
  ]
}

data "http" "atlantis_healthz" {
  url        = "https://${local.domains.atlantis}/healthz"
  depends_on = [time_sleep.wait_for_atlantis_https, data.dns_a_record_set.atlantis]

  retry {
    attempts     = 5
    min_delay_ms = 1000
    max_delay_ms = 5000
  }

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Atlantis healthz not reachable at https://${local.domains.atlantis}/healthz after waiting."
    }
  }
}
