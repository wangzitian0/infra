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
  zone_id = var.cloudflare_zone_id
  name    = "*"
  value   = var.vps_host
  type    = "A"
  proxied = false  # Internal services: no proxy
}

# Root domain: proxied for public access
resource "cloudflare_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  value   = var.vps_host
  type    = "A"
  proxied = true
}

# x-staging: environment services (proxied)
# Add more x-{env} records as needed
resource "cloudflare_record" "x_staging" {
  zone_id = var.cloudflare_zone_id
  name    = "x-staging"
  value   = var.vps_host
  type    = "A"
  proxied = true
}

# x-staging-* pattern: need explicit records for each service
# Example: x-staging-api, x-staging-posthog, etc.
# These will be added in L2 module as services are deployed
