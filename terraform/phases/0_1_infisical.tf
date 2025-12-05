# Phase 0.1: Infisical (Secrets Management)
# Namespace: iac
# Dependencies: Phase 1.1 (PostgreSQL)
# External: PostgreSQL (from 1_1_postgresql.tf)
# Embedded: Redis (managed by Infisical Helm chart)
# Helm chart: https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/

# Generate secure random keys for Infisical
resource "random_id" "infisical_encryption_key" {
  byte_length = 16
}

resource "random_id" "infisical_jwt_signup_secret" {
  byte_length = 16
}

resource "random_id" "infisical_jwt_refresh_secret" {
  byte_length = 16
}

resource "random_id" "infisical_jwt_auth_secret" {
  byte_length = 16
}

resource "random_id" "infisical_jwt_service_secret" {
  byte_length = 16
}

resource "random_id" "infisical_jwt_mfa_secret" {
  byte_length = 16
}

resource "random_id" "infisical_jwt_provider_secret" {
  byte_length = 16
}

# Helm release for Infisical with external PostgreSQL and embedded Redis
resource "helm_release" "infisical" {
  name             = "infisical"
  namespace        = var.namespaces["iac"]
  repository       = "https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/"
  chart            = "infisical-standalone"
  version          = var.infisical_chart_version
  create_namespace = false

  values = [
    yamlencode({
      # Configuration for Infisical Standalone Chart
      infisical = {
        image = {
          repository = "infisical/infisical"
          tag        = var.infisical_image_tag
        }
      }
      
      # Root level image config (fallback/alternative pattern)
      image = {
        repository = "infisical/infisical"
        tag        = var.infisical_image_tag
      }

      # Controller/Replica config (common standalone pattern)
      controller = {
        replicas = 1
      }

      # Explicitly point to existing secret (if supported by chart schema variations)
      kubeSecretRef = "infisical-secrets"

      # Disable embedded PostgreSQL
      postgresql = {
        enabled = false
      }

      # Embedded Redis
      redis = {
        enabled = true
        architecture = "standalone"
        auth = {
          enabled = false
        }
      }
    })
  ]

  depends_on = [
    helm_release.postgresql,
    kubernetes_secret.infisical_secrets
  ]
}

resource "kubernetes_secret" "infisical_secrets" {
  metadata {
    name      = "infisical-secrets"
    namespace = var.namespaces["iac"]
  }

  data = {
    # Database - using external PostgreSQL
    DB_CONNECTION_URI = "postgresql://infisical:${var.infisical_postgres_password}@postgresql.${var.namespaces["iac"]}.svc.cluster.local:5432/infisical"

    # Encryption keys
    ENCRYPTION_KEY           = random_id.infisical_encryption_key.hex
    AUTH_SECRET              = random_id.infisical_jwt_auth_secret.hex
    JWT_SIGNUP_SECRET        = random_id.infisical_jwt_signup_secret.hex
    JWT_REFRESH_SECRET       = random_id.infisical_jwt_refresh_secret.hex
    JWT_AUTH_SECRET          = random_id.infisical_jwt_auth_secret.hex
    JWT_SERVICE_SECRET       = random_id.infisical_jwt_service_secret.hex
    JWT_MFA_SECRET           = random_id.infisical_jwt_mfa_secret.hex
    JWT_PROVIDER_AUTH_SECRET = random_id.infisical_jwt_provider_secret.hex

    # Site configuration
    SITE_URL           = "http://infisical.local"
    INVITE_ONLY_SIGNUP = "false"

    # SMTP configuration
    SMTP_HOST         = "mailhog"
    SMTP_PORT         = "1025"
    SMTP_SECURE       = "false"
    SMTP_FROM_NAME    = "Infisical"
    SMTP_FROM_ADDRESS = "noreply@infisical.local"
    SMTP_USERNAME     = "noreply@infisical.local"
    SMTP_PASSWORD     = ""

    # Redis (embedded)
    REDIS_URL = "redis://:@infisical-redis-master:6379"
  }

}

output "infisical_endpoint" {
  value       = "infisical-backend.${var.namespaces["iac"]}.svc.cluster.local:8080"
  description = "Internal endpoint for Infisical backend"
}

output "infisical_access_via_port_forward" {
  value       = "kubectl -n ${var.namespaces["iac"]} port-forward svc/infisical-backend 8080:8080"
  description = "Command to access Infisical via port-forward"
}
