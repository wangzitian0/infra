# L1.2: Atlantis (Terraform CI/CD) - Foundation Layer
# Purpose: Self-hosted Terraform PR automation
# Note: Deployed in "nodep" namespace

resource "kubernetes_namespace" "nodep" {
  metadata {
    name = "nodep"
  }
}

resource "helm_release" "atlantis" {
  name       = "atlantis"
  namespace  = kubernetes_namespace.nodep.metadata[0].name
  repository = "https://runatlantis.github.io/helm-charts"
  chart      = "atlantis"
  version    = "4.25.0"

  values = [
    yamlencode(merge(
      {
        # GitHub Configuration
        orgAllowlist = "github.com/${var.github_org}/*"
        
        # Environment for R2 Backend
      environment = {
        AWS_ACCESS_KEY_ID     = var.aws_access_key_id
        AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
        R2_BUCKET             = var.r2_bucket
        R2_ACCOUNT_ID         = var.r2_account_id
        VPS_HOST              = var.vps_host
        VPS_SSH_KEY           = var.ssh_private_key
        CLOUDFLARE_API_TOKEN  = var.cloudflare_api_token
        CLOUDFLARE_ZONE_ID    = var.cloudflare_zone_id

        # Terraform variable injection (Atlantis pod)
        TF_VAR_vps_host             = var.vps_host
        TF_VAR_vps_user             = var.vps_user
        TF_VAR_ssh_private_key      = var.ssh_private_key
        TF_VAR_base_domain          = var.base_domain
        TF_VAR_cloudflare_api_token = var.cloudflare_api_token
        TF_VAR_cloudflare_zone_id   = var.cloudflare_zone_id
        TF_VAR_r2_bucket            = var.r2_bucket
        TF_VAR_r2_account_id        = var.r2_account_id
        TF_VAR_github_token         = var.github_token
        TF_VAR_atlantis_webhook_secret = var.atlantis_webhook_secret
        TF_VAR_github_app_id        = var.github_app_id
        TF_VAR_github_app_key       = var.github_app_key
        TF_VAR_k3s_channel          = var.k3s_channel
        TF_VAR_k3s_version          = var.k3s_version
        TF_VAR_cluster_name         = var.cluster_name
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
          enabled = true
          ingressClassName = "nginx"
          annotations = {
            "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
          }
          hosts = [
            {
              host = "i-atlantis.${var.base_domain}"
              paths = ["/"]
            }
          ]
          tls = [
            {
              secretName = "atlantis-tls"
              hosts      = ["i-atlantis.${var.base_domain}"]
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

        # Resource limits
        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "256Mi"
          }
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
  depends_on = [kubernetes_namespace.nodep]
}

output "atlantis_service" {
  value = "atlantis.${kubernetes_namespace.nodep.metadata[0].name}.svc.cluster.local:4141"
}

output "nodep_namespace" {
  value = kubernetes_namespace.nodep.metadata[0].name
}
