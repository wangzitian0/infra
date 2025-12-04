# Phase 0.1: Infisical (Secrets Management)
# Namespace: iac
# Dependencies: Phase 0.0 (k3s)
# Embedded: MongoDB, Redis (managed by Infisical Helm chart)
# Helm chart: https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/

resource "helm_repository" "infisical" {
  name           = "infisical"
  url            = "https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/"
  skip_update    = false
}

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

resource "random_password" "infisical_mongodb_user" {
  length  = 16
  special = false
}

resource "random_password" "infisical_mongodb_root" {
  length  = 20
  special = false
}

# Helm release for Infisical with embedded MongoDB and Redis
resource "helm_release" "infisical" {
  name            = "infisical"
  namespace       = var.namespaces["iac"]
  repository      = helm_repository.infisical.name
  chart           = "infisical"
  version         = var.infisical_chart_version
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
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }

      backendEnvironmentVariables = {
        ENCRYPTION_KEY         = random_id.infisical_encryption_key.hex
        JWT_SIGNUP_SECRET      = random_id.infisical_jwt_signup_secret.hex
        JWT_REFRESH_SECRET     = random_id.infisical_jwt_refresh_secret.hex
        JWT_AUTH_SECRET        = random_id.infisical_jwt_auth_secret.hex
        JWT_SERVICE_SECRET     = random_id.infisical_jwt_service_secret.hex
        JWT_MFA_SECRET         = random_id.infisical_jwt_mfa_secret.hex
        JWT_PROVIDER_AUTH_SECRET = random_id.infisical_jwt_provider_secret.hex
        SITE_URL               = "http://infisical.local"
        INVITE_ONLY_SIGNUP     = false
        SMTP_HOST              = "mailhog"
        SMTP_PORT              = 1025
        SMTP_SECURE            = false
        SMTP_FROM_NAME         = "Infisical"
        SMTP_FROM_ADDRESS      = "noreply@infisical.local"
        SMTP_USERNAME          = "noreply@infisical.local"
        SMTP_PASSWORD          = ""
        REDIS_URL              = "redis://:@redis-master:6379"
      }

      mongodb = {
        auth = {
          enabled = true
          rootUser = "root"
          rootPassword = random_password.infisical_mongodb_root.result
          usernames = ["infisical"]
          passwords = [random_password.infisical_mongodb_user.result]
          databases = ["infisical"]
        }
        architecture = "standalone"
        persistence = {
          enabled = true
          size    = "20Gi"
          storageClassName = "local-path"
        }
        resources = {
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }
      }

      redis = {
        auth = {
          enabled = false
        }
        architecture = "standalone"
        persistence = {
          enabled = true
          size    = "10Gi"
          storageClassName = "local-path"
        }
        resources = {
          requests = {
            cpu    = "50m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "250m"
            memory = "256Mi"
          }
        }
      }

      mailhog = {
        enabled = true
        ingress = {
          enabled = false
        }
      }

      ingress = {
        enabled = false
      }
    })
  ]

  depends_on = [
    var.namespaces
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
