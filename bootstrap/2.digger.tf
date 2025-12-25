# L1.2: Digger Orchestrator (Terraform CI/CD)
# Purpose: Self-hosted Digger backend for on_commit_to_default support
# Note: Replaces Atlantis - enables post-merge apply via GitHub Actions

resource "kubernetes_namespace" "bootstrap" {
  metadata {
    name = local.k8s.ns_bootstrap
    labels = {
      "layer" = "L1"
    }
  }
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
          repository = "registry.digger.dev/diggerhq/digger_backend"
          tag        = "v0.6.101"
        }

        # Enable Bearer Token authentication (required for GitHub Actions)
        # By default only HTTP_BASIC_AUTH is enabled
        customEnv = [
          {
            name  = "BEARER_AUTH"
            value = "1"
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
        postgres = {
          host     = local.k8s.platform_pg_host
          database = "digger"
          user     = "postgres"
          password = var.vault_postgres_password
          port     = "5432"
          sslmode  = "disable"
        }

        # Secrets configuration
        secret = {
          useExistingSecret     = false
          httpBasicAuthUsername = "admin"
          httpBasicAuthPassword = var.digger_http_password
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
    time_sleep.wait_for_platform_pg
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
