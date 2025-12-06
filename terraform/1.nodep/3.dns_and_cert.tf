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
# Architecture: Wildcard DNS + Ingress-based routing
# - All HTTP/HTTPS services (80/443) route through Ingress Controller
# - Cloudflare proxy (orange cloud) enabled for CDN & DDoS protection
# - Special ports (e.g., 6443) use DNS-only (grey cloud)
# =============================================================================

# Wildcard record: routes all subdomains to Ingress Controller
# Individual services are differentiated by Ingress Host rules
resource "cloudflare_record" "wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  value   = var.vps_host
  type    = "A"
  proxied = true
}

# Root domain (optional): direct access to frontend/default service
resource "cloudflare_record" "root" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  value   = var.vps_host
  type    = "A"
  proxied = true
}

# K3s API (port 6443) - MUST be DNS-only (grey cloud)
# Cloudflare proxy doesn't support non-standard ports
resource "cloudflare_record" "k3s" {
  zone_id = var.cloudflare_zone_id
  name    = "i-k3s"
  value   = var.vps_host
  type    = "A"
  proxied = false
}
