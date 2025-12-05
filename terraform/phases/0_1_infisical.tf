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
  chart            = "infisical"
  version          = var.infisical_chart_version
  create_namespace = false

  values = [
    yamlencode({
      backend = {
        replicaCount = 1
        image = {
          tag = var.infisical_image_tag
        }
        service = {
          type = "ClusterIP"
        }
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
        }
      }

      backendEnvironmentVariables = {
        # Database - using external PostgreSQL
        DB_CONNECTION_URI = "postgresql://infisical:${var.postgres_password}@postgresql.${var.namespaces["iac"]}.svc.cluster.local:5432/infisical"

        # Encryption keys
        ENCRYPTION_KEY           = random_id.infisical_encryption_key.hex
        JWT_SIGNUP_SECRET        = random_id.infisical_jwt_signup_secret.hex
        JWT_REFRESH_SECRET       = random_id.infisical_jwt_refresh_secret.hex
        JWT_AUTH_SECRET          = random_id.infisical_jwt_auth_secret.hex
        JWT_SERVICE_SECRET       = random_id.infisical_jwt_service_secret.hex
        JWT_MFA_SECRET           = random_id.infisical_jwt_mfa_secret.hex
        JWT_PROVIDER_AUTH_SECRET = random_id.infisical_jwt_provider_secret.hex

        # Site configuration
        SITE_URL           = "http://infisical.local"
        INVITE_ONLY_SIGNUP = false

        # SMTP configuration (using mailhog for dev)
        SMTP_HOST         = "mailhog"
        SMTP_PORT         = 1025
        SMTP_SECURE       = false
        SMTP_FROM_NAME    = "Infisical"
        SMTP_FROM_ADDRESS = "noreply@infisical.local"
        SMTP_USERNAME     = "noreply@infisical.local"
        SMTP_PASSWORD     = ""

        # Redis (embedded)
        REDIS_URL = "redis://:@infisical-redis-master:6379"
      }

      # Disable embedded PostgreSQL (using external)
      postgresql = {
        enabled = false
      }

      # Embedded Redis for caching
      redis = {
        enabled = true
        auth = {
          enabled = false
        }
        architecture = "standalone"
        persistence = {
          enabled      = true
          size         = "1Gi"
          storageClass = "local-path"
        }
        resources = {
          requests = {
            cpu    = "25m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }

      # Mailhog disabled to save resources (enable later if needed)
      mailhog = {
        enabled = false
      }

      ingress = {
        enabled = false
      }
    })
  ]

  depends_on = [
    helm_release.postgresql
  ]
}

output "infisical_endpoint" {
  value       = "infisical-backend.${var.namespaces["iac"]}.svc.cluster.local:8080"
  description = "Internal endpoint for Infisical backend"
}

output "infisical_access_via_port_forward" {
  value       = "kubectl -n ${var.namespaces["iac"]} port-forward svc/infisical-backend 8080:8080"
  description = "Command to access Infisical via port-forward"
}
