# L2.3: DNS & Certificate Management (Cloudflare + CertManager)

locals {
  infra_dns_records = {
    atlantis   = true  # HTTPS via proxy
    secrets    = true  # HTTPS via proxy
    kdashboard = true  # HTTPS via proxy
    kcloud     = true  # HTTPS via proxy
    kapi       = true  # HTTPS via proxy
    signoz     = true  # HTTPS via proxy
    posthog    = true  # HTTPS via proxy
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

  set {
    name  = "installCRDs"
    value = "true"
  }

  depends_on = [kubernetes_namespace.cert_manager]
}

# 4. ClusterIssuer (Let's Encrypt Production)
# Note: Using null_resource + kubectl instead of kubernetes_manifest 
# because kubernetes_manifest requires CRDs to exist during plan,
# which fails in CI when CRDs haven't been installed yet.
resource "null_resource" "cluster_issuer_letsencrypt_prod" {
  triggers = {
    # Re-run if these change
    email       = "admin@${var.base_domain}"
    secret_name = kubernetes_secret.cloudflare_api_token.metadata[0].name
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl --kubeconfig=${local.kubeconfig_path} apply -f - <<EOF
      apiVersion: cert-manager.io/v1
      kind: ClusterIssuer
      metadata:
        name: letsencrypt-prod
      spec:
        acme:
          email: admin@${var.base_domain}
          server: https://acme-v02.api.letsencrypt.org/directory
          privateKeySecretRef:
            name: letsencrypt-prod
          solvers:
          - dns01:
              cloudflare:
                apiTokenSecretRef:
                  name: cloudflare-api-token-secret
                  key: api-token
      EOF
    EOT
  }

  depends_on = [helm_release.cert_manager, kubernetes_secret.cloudflare_api_token]
}

# 5. Wildcard Certificate (covers *.domain and domain)
# Using DNS-01 challenge via Cloudflare for wildcard cert
resource "null_resource" "wildcard_certificate_public" {
  triggers = {
    domains = join(",", local.base_cert_domains)
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl --kubeconfig=${local.kubeconfig_path} apply -f - <<EOF
      apiVersion: cert-manager.io/v1
      kind: Certificate
      metadata:
        name: wildcard-tls-public
        namespace: ${kubernetes_namespace.cert_manager.metadata[0].name}
      spec:
        secretName: wildcard-tls-public
        issuerRef:
          name: letsencrypt-prod
          kind: ClusterIssuer
        dnsNames:
${local.base_cert_domains_yaml}
      EOF
    EOT
  }

  depends_on = [null_resource.cluster_issuer_letsencrypt_prod]
}

resource "null_resource" "wildcard_certificate_internal" {
  triggers = {
    domains = join(",", local.internal_cert_domains)
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl --kubeconfig=${local.kubeconfig_path} apply -f - <<EOF
      apiVersion: cert-manager.io/v1
      kind: Certificate
      metadata:
        name: wildcard-tls-internal
        namespace: ${kubernetes_namespace.cert_manager.metadata[0].name}
      spec:
        secretName: wildcard-tls-internal
        issuerRef:
          name: letsencrypt-prod
          kind: ClusterIssuer
        dnsNames:
${local.internal_cert_domains_yaml}
      EOF
    EOT
  }

  depends_on = [null_resource.cluster_issuer_letsencrypt_prod]
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
  value           = var.vps_host
  type            = "A"
  proxied         = true
  allow_overwrite = true
}

# Explicit infra records with per-service proxy settings (k3s stays DNS-only)
resource "cloudflare_record" "infra_records" {
  for_each        = local.infra_dns_records
  zone_id         = local.internal_zone_id
  name            = each.key
  value           = var.vps_host
  type            = "A"
  proxied         = each.value
  allow_overwrite = true
}

resource "cloudflare_record" "wildcard_public" {
  zone_id         = var.cloudflare_zone_id
  name            = "*"
  value           = var.vps_host
  type            = "A"
  proxied         = true
  allow_overwrite = true
}

# Root domain: proxied for public access
resource "cloudflare_record" "root" {
  zone_id         = var.cloudflare_zone_id
  name            = "@"
  value           = var.vps_host
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
  value           = var.vps_host
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
resource "null_resource" "validate_dns" {
  triggers = {
    host   = local.domains.atlantis
    vps_ip = var.vps_host
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating DNS resolution for ${local.domains.atlantis}..."
      RESOLVED_IP=$(dig +short ${local.domains.atlantis} | head -1)
      if [ -z "$RESOLVED_IP" ]; then
        echo "ERROR: DNS resolution failed for ${local.domains.atlantis}"
        exit 1
      fi
      echo "OK: ${local.domains.atlantis} resolves to $RESOLVED_IP"
    EOT
  }

  depends_on = [cloudflare_record.infra_records]
}

# Validate HTTPS certificate is valid for Atlantis host
resource "null_resource" "validate_cert" {
  triggers = {
    domain = local.domains.atlantis
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating HTTPS certificate for ${local.domains.atlantis}..."
      # Wait for cert to be issued (max 2 minutes)
      for i in $(seq 1 24); do
        if curl -sf --connect-timeout 5 https://${local.domains.atlantis}/healthz >/dev/null 2>&1; then
          echo "OK: HTTPS certificate is valid"
          exit 0
        fi
        echo "Waiting for certificate... ($i/24)"
        sleep 5
      done
      echo "WARNING: Certificate validation timeout (may still be issuing)"
    EOT
  }

  depends_on = [null_resource.wildcard_certificate_internal, null_resource.validate_dns]
}

# Validate Atlantis health (nodep module check)
resource "null_resource" "validate_atlantis" {
  triggers = {
    atlantis_release = helm_release.atlantis.metadata[0].revision
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating Atlantis health..."
      HEALTH=$(curl -sf --connect-timeout 10 https://${local.domains.atlantis}/healthz || echo "FAIL")
      if [ "$HEALTH" = "FAIL" ]; then
        echo "WARNING: Atlantis healthz not reachable (may be starting up)"
      else
        echo "OK: Atlantis is healthy"
      fi
    EOT
  }

  depends_on = [helm_release.atlantis, null_resource.validate_cert]
}
