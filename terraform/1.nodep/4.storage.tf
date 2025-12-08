# L1.4: Storage safety for local-path
# Goal: keep critical PVCs (e.g., Infisical Postgres) on /data and avoid auto-deletion on PVC removal

locals {
  local_path_config_json = jsonencode({
    nodePathMap = [
      {
        node  = "*"
        paths = ["/data/local-path-provisioner", "/opt/local-path-provisioner"]
      }
    ]
  })
}

# Patch default local-path-provisioner config to write volumes under /data/local-path-provisioner
resource "kubernetes_manifest" "local_path_config" {
  manifest = {
    apiVersion = "v1"
    kind       = "ConfigMap"
    metadata = {
      name      = "local-path-config"
      namespace = "kube-system"
    }
    data = {
      "config.json" = local.local_path_config_json
    }
  }

  field_manager   = "terraform"
  force_conflicts = true
  depends_on      = [null_resource.kubeconfig]
}

# New StorageClass that keeps PVs after PVC deletion (manual cleanup required)
resource "kubernetes_storage_class" "local_path_retain" {
  metadata {
    name = "local-path-retain"
  }

  storage_provisioner    = "rancher.io/local-path"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  depends_on = [null_resource.kubeconfig]
}

# Restart local-path-provisioner when config changes so new paths take effect
resource "null_resource" "restart_local_path_provisioner" {
  triggers = {
    config_hash = sha1(local.local_path_config_json)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      export KUBECONFIG="${var.kubeconfig_path}"
      kubectl rollout restart deployment/local-path-provisioner -n kube-system
      kubectl rollout status deployment/local-path-provisioner -n kube-system --timeout=2m
    EOT
  }

  depends_on = [kubernetes_manifest.local_path_config]
}
