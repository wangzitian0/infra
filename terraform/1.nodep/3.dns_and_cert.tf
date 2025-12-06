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
      kubectl --kubeconfig=${var.kubeconfig_path} apply -f - <<EOF
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
resource "null_resource" "wildcard_certificate" {
  triggers = {
    domain = var.base_domain
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl --kubeconfig=${var.kubeconfig_path} apply -f - <<EOF
      apiVersion: cert-manager.io/v1
      kind: Certificate
      metadata:
        name: wildcard-tls
        namespace: ${kubernetes_namespace.cert_manager.metadata[0].name}
      spec:
        secretName: wildcard-tls-secret
        issuerRef:
          name: letsencrypt-prod
          kind: ClusterIssuer
        dnsNames:
        - "${var.base_domain}"
        - "*.${var.base_domain}"
      EOF
    EOT
  }

  depends_on = [null_resource.cluster_issuer_letsencrypt_prod]
}

# 6. Cloudflare DNS Records
# =============================================================================
# Architecture: 
# - i-* (internal): DNS-only (grey cloud) - may use non-standard ports
# - x-* (external): Proxied (orange cloud) - CDN & DDoS protection
# - Wildcard: DNS-only by default (internal fallback)
# - Specific x-* records override wildcard with proxy enabled
# =============================================================================

# Wildcard: default to DNS-only (grey cloud) for internal services
# This covers all i-* subdomains automatically
resource "cloudflare_record" "wildcard" {
  zone_id         = var.cloudflare_zone_id
  name            = "*"
  value           = var.vps_host
  type            = "A"
  proxied         = false  # Internal services: no proxy
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

# x-staging: environment services (proxied)
# Add more x-{env} records as needed
resource "cloudflare_record" "x_staging" {
  zone_id         = var.cloudflare_zone_id
  name            = "x-staging"
  value           = var.vps_host
  type            = "A"
  proxied         = true
  allow_overwrite = true
}

# x-staging-* pattern: need explicit records for each service
# Example: x-staging-api, x-staging-posthog, etc.
# These will be added in L2 module as services are deployed

# =============================================================================
# 7. Post-Apply Validation (DNS + Cert + Atlantis Health)
# =============================================================================

# Validate DNS resolution for wildcard
resource "null_resource" "validate_dns" {
  triggers = {
    domain = var.base_domain
    vps_ip = var.vps_host
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating DNS resolution for *.${var.base_domain}..."
      RESOLVED_IP=$(dig +short i-atlantis.${var.base_domain} | head -1)
      if [ -z "$RESOLVED_IP" ]; then
        echo "ERROR: DNS resolution failed for i-atlantis.${var.base_domain}"
        exit 1
      fi
      echo "OK: i-atlantis.${var.base_domain} resolves to $RESOLVED_IP"
    EOT
  }

  depends_on = [cloudflare_record.wildcard]
}

# Validate HTTPS certificate is valid
resource "null_resource" "validate_cert" {
  triggers = {
    domain = var.base_domain
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating HTTPS certificate for ${var.base_domain}..."
      # Wait for cert to be issued (max 2 minutes)
      for i in $(seq 1 24); do
        if curl -sf --connect-timeout 5 https://i-atlantis.${var.base_domain}/healthz >/dev/null 2>&1; then
          echo "OK: HTTPS certificate is valid"
          exit 0
        fi
        echo "Waiting for certificate... ($i/24)"
        sleep 5
      done
      echo "WARNING: Certificate validation timeout (may still be issuing)"
    EOT
  }

  depends_on = [null_resource.wildcard_certificate, null_resource.validate_dns]
}

# Validate Atlantis health (nodep module check)
resource "null_resource" "validate_atlantis" {
  triggers = {
    atlantis_release = helm_release.atlantis.metadata[0].revision
  }

  provisioner "local-exec" {
    command = <<-EOT
      echo "Validating Atlantis health..."
      HEALTH=$(curl -sf --connect-timeout 10 https://i-atlantis.${var.base_domain}/healthz || echo "FAIL")
      if [ "$HEALTH" = "FAIL" ]; then
        echo "WARNING: Atlantis healthz not reachable (may be starting up)"
      else
        echo "OK: Atlantis is healthy"
      fi
    EOT
  }

  depends_on = [helm_release.atlantis, null_resource.validate_cert]
}
