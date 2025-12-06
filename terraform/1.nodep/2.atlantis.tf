# L1.2: Atlantis (Terraform CI/CD) - Foundation Layer
# Purpose: Self-hosted Terraform PR automation
# Note: Deployed in L1 because it manages the infra repo itself

# Atlantis namespace (iac = Infrastructure as Code)
resource "kubernetes_namespace" "iac" {
  metadata {
    name = "iac"
  }
}

resource "helm_release" "atlantis" {
  name       = "atlantis"
  namespace  = kubernetes_namespace.iac.metadata[0].name
  repository = "https://runatlantis.github.io/helm-charts"
  chart      = "atlantis"
  version    = "4.25.0"

  values = [
    yamlencode({
      # GitHub Configuration
      orgAllowlist = "github.com/${var.github_org}/*"
      github = {
        user   = var.github_user
        token  = var.github_token
        secret = var.atlantis_webhook_secret
      }

      # Environment for R2 Backend
      environment = {
        AWS_ACCESS_KEY_ID     = var.aws_access_key_id
        AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
        R2_BUCKET             = var.r2_bucket
        R2_ACCOUNT_ID         = var.r2_account_id
        VPS_HOST              = var.vps_host
        VPS_SSH_KEY           = var.ssh_private_key
      }

      # Server-side repo config (allows custom workflows)
      repoConfig = yamlencode({
        repos = [{
          id                     = "github.com/${var.github_org}/infra"
          allow_custom_workflows = true
          allowed_overrides      = ["workflow", "apply_requirements"]
        }]
      })

      # Ingress via Cloudflare Tunnel (Service only, Tunnel handles routing)
      service = {
        type = "ClusterIP"
        port = 4141
      }

      # Persistence for plan files and locks
      persistence = {
        enabled      = true
        size         = "5Gi"
        storageClass = "local-path"
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
    })
  ]

  depends_on = [kubernetes_namespace.iac]
}

output "atlantis_service" {
  value = "atlantis.${kubernetes_namespace.iac.metadata[0].name}.svc.cluster.local:4141"
}

output "iac_namespace" {
  value = kubernetes_namespace.iac.metadata[0].name
}
