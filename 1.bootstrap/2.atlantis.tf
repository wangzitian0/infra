# L1.2: Atlantis (Terraform CI/CD) - Foundation Layer
# Purpose: Self-hosted Terraform PR automation
# Note: Deployed in "bootstrap" namespace (L1 layer naming convention)

resource "kubernetes_namespace" "bootstrap" {
  metadata {
    name = "bootstrap"
    labels = {
      "layer" = "L1"
    }
  }
}

# TODO: Add Casdoor SSO or stricter IP allowlist for Atlantis UI
#       Currently protected by Basic Auth only.
#       See: https://github.com/wangzitian0/infra/issues/XXX

resource "helm_release" "atlantis" {
  name       = "atlantis"
  namespace  = kubernetes_namespace.bootstrap.metadata[0].name
  repository = "https://runatlantis.github.io/helm-charts"
  chart      = "atlantis"
  version    = "4.25.0"
  timeout    = 300
  wait       = true

  values = [
    yamlencode(merge(
      {
        # GitHub Configuration
        orgAllowlist = "github.com/${var.github_org}/*"
        atlantisUrl  = "https://${local.domains.atlantis}"

        # Terraform version - 1.11+ required for WriteOnly attributes (e.g. clickhousedbops)
        defaultTFVersion = "1.11.0"
        # Environment for R2 Backend (AWS_* used by S3 backend)
        # AND TF_VAR_* for Terraform variables
        environment = {
          # R2 Backend Authentication (required by terraform init)
          AWS_ACCESS_KEY_ID     = var.aws_access_key_id
          AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
          R2_BUCKET             = var.r2_bucket
          R2_ACCOUNT_ID         = var.r2_account_id

          # Terraform Variables (TF_VAR_xxx format for auto-injection)
          TF_VAR_vps_host                = var.vps_host
          TF_VAR_ssh_private_key         = var.ssh_private_key
          TF_VAR_r2_bucket               = var.r2_bucket
          TF_VAR_r2_account_id           = var.r2_account_id
          TF_VAR_aws_access_key_id       = var.aws_access_key_id
          TF_VAR_aws_secret_access_key   = var.aws_secret_access_key
          TF_VAR_base_domain             = var.base_domain
          TF_VAR_internal_domain         = local.internal_domain
          TF_VAR_cloudflare_api_token    = var.cloudflare_api_token
          TF_VAR_cloudflare_zone_id      = var.cloudflare_zone_id
          TF_VAR_internal_zone_id        = local.internal_zone_id
          TF_VAR_vault_postgres_password = var.vault_postgres_password
          TF_VAR_github_token            = var.github_token
          TF_VAR_atlantis_webhook_secret = var.atlantis_webhook_secret
          TF_VAR_github_app_id           = var.github_app_id
          TF_VAR_github_app_key          = var.github_app_key
          # OAuth2-Proxy (GitHub OAuth for Dashboard protection)
          TF_VAR_github_oauth_client_id     = var.github_oauth_client_id
          TF_VAR_github_oauth_client_secret = var.github_oauth_client_secret
          # Casdoor SSO
          TF_VAR_casdoor_admin_password = var.casdoor_admin_password
          # Portal SSO Gate - enables OIDC apps for Vault/Dashboard/Kubero
          TF_VAR_enable_portal_sso_gate = "true"
          # L3 Vault access
          TF_VAR_vault_root_token = var.vault_root_token
        }

        # Server-side repo config (allows custom workflows)
        repoConfig = yamlencode({
          repos = [{
            id                     = "github.com/${var.github_org}/infra"
            allow_custom_workflows = true
            allowed_overrides      = ["workflow", "apply_requirements"]
          }]
        })

        # Ingress (TLS via Cert Manager + Cloudflare)
        ingress = {
          enabled          = true
          ingressClassName = "traefik"
          annotations = {
            "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
            # TODO: Add IP allowlist or SSO for additional security
            # Currently protected by Basic Auth (see basicAuth config below)
          }
          hosts = [
            {
              host  = local.domains.atlantis
              paths = ["/"]
            }
          ]
          tls = [
            {
              secretName = "atlantis-tls"
              hosts      = [local.domains.atlantis]
            }
          ]
        }

        service = {
          type = "ClusterIP"
          port = 4141
        }

        # Persistence for plan files and locks
        volumeClaim = {
          enabled          = true
          dataStorage      = "5Gi"
          storageClassName = "local-path"
        }

        # Basic Auth for Web UI (security hardening)
        basicAuth = {
          username = var.atlantis_web_username
          password = var.atlantis_web_password
        }

        # Resource limits (increased for production terraform operations)
        resources = {
          limits = {
            cpu    = "3000m"
            memory = "6Gi"
          }
          requests = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }

        # Speed up readiness checks (default periodSeconds=60 is too slow)
        readinessProbe = {
          periodSeconds = 10
        }
        livenessProbe = {
          periodSeconds = 10
        }
      },
      # GitHub App Auth (preferred when configured)
      var.github_app_id != "" ? {
        githubApp = {
          id     = var.github_app_id
          key    = var.github_app_key
          secret = var.atlantis_webhook_secret
        }
      } : {},
      # PAT Auth (fallback when GitHub App not configured)
      var.github_app_id == "" ? {
        github = {
          user   = var.github_user
          token  = var.github_token
          secret = var.atlantis_webhook_secret
        }
      } : {}
    ))
  ]

  depends_on = [kubernetes_namespace.bootstrap]

  lifecycle {
    precondition {
      condition     = var.github_app_id != "" || var.github_token != ""
      error_message = "Either github_app_id or github_token must be set for Atlantis GitHub integration."
    }
    precondition {
      condition     = var.atlantis_webhook_secret != ""
      error_message = "atlantis_webhook_secret is required for secure webhook verification."
    }
  }
}

output "atlantis_service" {
  value = "atlantis.${kubernetes_namespace.bootstrap.metadata[0].name}.svc.cluster.local:4141"
}

output "bootstrap_namespace" {
  value = kubernetes_namespace.bootstrap.metadata[0].name
}

# ClusterRoleBinding for Atlantis to manage all Terraform resources
# Required because Atlantis needs to create/manage namespaces, cluster-wide resources
resource "kubernetes_cluster_role_binding" "atlantis_cluster_admin" {
  metadata {
    name = "atlantis-cluster-admin"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "atlantis"
    namespace = kubernetes_namespace.bootstrap.metadata[0].name
  }

  depends_on = [helm_release.atlantis]
}
