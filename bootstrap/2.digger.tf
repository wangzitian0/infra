# L1.2: Digger Orchestrator (Terraform CI/CD)
# Purpose: Self-hosted Digger backend for on_commit_to_default support
# Note: Replaces Atlantis - enables post-merge apply via GitHub Actions
# 

import {
  to = kubernetes_namespace.bootstrap
  id = "bootstrap"
}
resource "kubernetes_namespace" "bootstrap" {
  metadata {
    name = local.k8s.ns_bootstrap
    labels = {
      "layer" = "L1"
    }
  }
}

# Digger PostgreSQL password secret
# Managed separately from Helm to ensure password consistency
import {
  to = kubernetes_secret.digger_postgres_password
  id = "bootstrap/digger-digger-backend-postgres-secret"
}

resource "kubernetes_secret" "digger_postgres_password" {
  metadata {
    name      = "digger-digger-backend-postgres-secret"
    namespace = kubernetes_namespace.bootstrap.metadata[0].name
    labels = {
      "app.kubernetes.io/managed-by" = "Terraform"
      "app.kubernetes.io/part-of"    = "digger"
    }
  }

  data = {
    postgres-password = var.vault_postgres_password
  }

  depends_on = [kubernetes_namespace.bootstrap]

  lifecycle {
    ignore_changes = [
      metadata[0].annotations["meta.helm.sh/release-name"],
      metadata[0].annotations["meta.helm.sh/release-namespace"],
      metadata[0].labels["app.kubernetes.io/managed-by"]
    ]
  }
}

import {
  to = helm_release.digger
  id = "bootstrap/digger"
}
resource "helm_release" "digger" {
  name       = "digger"
  namespace  = kubernetes_namespace.bootstrap.metadata[0].name
  repository = "https://diggerhq.github.io/helm-charts"
  chart      = "digger-backend"
  version    = "0.1.12"
  timeout    = 300
  wait       = true

  values = [
    yamlencode({
      digger = {
        image = {
          # Use latest stable version to fix nil pointer crash in PR event handling
          repository = "registry.digger.dev/diggerhq/digger_backend"
          tag        = "v0.6.138"
        }

        # Use NOOP_AUTH for self-hosted Orchestrator (official recommendation)
        # Future: integrate with Casdoor for additional authentication layer
        customEnv = [
          {
            name  = "NOOP_AUTH"
            value = "1"
          },
          {
            name  = "HTTP_BASIC_AUTH"
            value = "0"
          },
          # Enable internal and API endpoints (required for self-hosted mode)
          {
            name  = "DIGGER_ENABLE_INTERNAL_ENDPOINTS"
            value = "true"
          },
          {
            name  = "DIGGER_ENABLE_API_ENDPOINTS"
            value = "true"
          },
          {
            name  = "DIGGER_INTERNAL_SECRET"
            value = "digger-orchestrator-secret-2025"
          },
          {
            name  = "HOSTNAME"
            value = "https://${local.domains.digger}"
          },
          # Explicitly set ALLOW_DIRTY to allow existing schema
          {
            name  = "ALLOW_DIRTY"
            value = "true"
          }
        ]

        # Resource limits
        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }

        # Service configuration
        service = {
          type = "ClusterIP"
          port = 3000
        }

        # Ingress (TLS via Cert Manager)
        ingress = {
          enabled   = true
          className = "traefik"
          host      = local.domains.digger
          annotations = {
            "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
          }
          tls = {
            secretName = "digger-tls"
          }
        }

        # PostgreSQL configuration (use Platform CNPG)
        # Chart creates DATABASE_URL and references password from secret
        postgres = {
          host        = local.k8s.platform_pg_host
          database    = "digger"
          user        = "postgres"
          port        = "5432"
          sslmode     = "disable"
          allow_dirty = true # Database already has schema/tables
          # Chart expects secret with key "postgres-password"
          # We manage this secret externally via kubernetes_secret.digger_postgres_password
        }

        # Secrets configuration 
        # Note: HTTP Basic Auth is enabled by chart default via secret.httpBasicAuthUsername
        # To disable, we must set empty values here
        secret = {
          useExistingSecret     = false
          httpBasicAuthUsername = "" # Disable HTTP Basic Auth
          httpBasicAuthPassword = "" # Disable HTTP Basic Auth
          bearerAuthToken       = var.digger_bearer_token
          hostname              = local.domains.digger
          githubOrg             = var.github_org
          githubAppID           = var.infra_flash_app_id
          githubAppClientID     = var.github_oauth_client_id
          githubAppClientSecret = var.github_oauth_client_secret
          githubAppKeyFile      = base64encode(var.infra_flash_app_key)
          githubWebhookSecret   = var.digger_webhook_secret
        }
      }

      # Disable built-in postgres (use external CNPG)
      postgres = {
        enabled = false
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.bootstrap,
    time_sleep.wait_for_platform_pg,
    kubernetes_secret.digger_postgres_password
  ]

  lifecycle {
    precondition {
      condition     = var.infra_flash_app_id != ""
      error_message = "infra_flash_app_id is required for Digger GitHub integration."
    }
    precondition {
      condition     = var.digger_bearer_token != ""
      error_message = "digger_bearer_token is required for API authentication."
    }
    postcondition {
      condition = (
        try(yamldecode(self.values[0]).digger.ingress.enabled, false) &&
        try(yamldecode(self.values[0]).digger.ingress.tls.secretName, "") != ""
      )
      error_message = "Digger ingress must be configured with HTTPS."
    }
  }
}

output "digger_url" {
  value       = "https://${local.domains.digger}"
  description = "Digger Orchestrator URL"
}

output "digger_webhook_url" {
  value       = "https://${local.domains.digger}/github-app-webhook"
  description = "GitHub webhook URL for Digger"
}

# PostgreSQL Password Synchronization Notes:
#
# Fresh Bootstrap (Day 0):
#   CNPG initializes PostgreSQL with password from platform-pg-superuser secret.
#   The superuserSecret reference ensures correct password from the start.
#   No manual intervention needed.
#
# Password Drift Recovery (Manual Fix):
#   If platform-pg-superuser secret is updated after initial deployment, CNPG's
#   cnpg.io/reload label only updates password files, NOT PostgreSQL's password hash.
#   
#   To fix drift manually:
#   1. Verify secret: kubectl get secret -n platform platform-pg-superuser -o jsonpath='{.data.password}' | base64 -d
#   2. Sync password: kubectl exec -n platform platform-pg-1 -- psql -U postgres -c "ALTER USER postgres WITH PASSWORD '\$NEW_PASS';"
#   3. Restart consumers: kubectl rollout restart -n bootstrap deployment/digger-digger-backend-web
#
# Why no automated Job?
#   - Fresh deploys don't need it (CNPG handles correctly)
#   - Drift recovery is rare operational event
#   - Automated Job adds complexity and RBAC surface
#   - Manual recovery is explicit and auditable
