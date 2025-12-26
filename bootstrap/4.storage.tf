# L1.4: Storage safety for local-path
# Goal: keep critical PVCs (e.g., Vault Raft storage) on /data and avoid auto-deletion on PVC removal

locals {
  # config.json: use /data as primary path for persistent volumes
  local_path_config_json = jsonencode({
    nodePathMap = [
      {
        node  = "DEFAULT_PATH_FOR_NON_LISTED_NODES"
        paths = ["/data/local-path-provisioner"]
      }
    ]
  })

  # helperPod.yaml: k3s default helper pod spec (required by local-path-provisioner)
  local_path_helper_pod = <<-YAML
    apiVersion: v1
    kind: Pod
    metadata:
      name: helper-pod
    spec:
      containers:
      - name: helper-pod
        image: "rancher/mirrored-library-busybox:1.36.1"
        imagePullPolicy: IfNotPresent
  YAML

  # setup script: create volume directory with proper permissions
  local_path_setup = <<-SCRIPT
    #!/bin/sh
    set -eu
    mkdir -m 0777 -p "$${VOL_DIR}"
    chmod 700 "$${VOL_DIR}/.."
  SCRIPT

  # teardown script: cleanup on PVC deletion (only runs for Delete policy)
  local_path_teardown = <<-SCRIPT
    #!/bin/sh
    set -eu
    rm -rf "$${VOL_DIR}"
  SCRIPT
}

# Patch default local-path-provisioner config to write volumes under /data/local-path-provisioner
import {
  to = kubernetes_config_map_v1.local_path_config
  id = "kube-system/local-path-config"
}
resource "kubernetes_config_map_v1" "local_path_config" {
  metadata {
    name      = "local-path-config"
    namespace = "kube-system"
  }

  data = {
    "config.json"    = local.local_path_config_json
    "helperPod.yaml" = local.local_path_helper_pod
    "setup"          = local.local_path_setup
    "teardown"       = local.local_path_teardown
  }

  depends_on = [null_resource.kubeconfig]
}

# New StorageClass that keeps PVs after PVC deletion (manual cleanup required)
import {
  to = kubernetes_storage_class.local_path_retain
  id = "local-path-retain"
}
resource "kubernetes_storage_class" "local_path_retain" {
  metadata {
    name = "local-path-retain"
  }

  storage_provisioner    = "rancher.io/local-path"
  reclaim_policy         = "Retain"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  depends_on = [null_resource.kubeconfig]

  lifecycle {
    postcondition {
      condition     = self.reclaim_policy == "Retain"
      error_message = "StorageClass reclaim_policy must be 'Retain'."
    }
  }
}

# Restart local-path-provisioner when config changes
# 
# Previous attempt used kubectl_manifest to patch Deployment with config hash annotation,
# but the spec was invalid (missing required spec.selector and spec.template.metadata.labels).
# 
# Current approach: Manual operator intervention when needed
# - ConfigMap changes are detected by K3s >= v1.21 and trigger pod restart automatically
# - For older versions or to force immediate reload, operators can run:
#   kubectl rollout restart deployment/local-path-provisioner -n kube-system
# 
# See: docs/change_log/2025-12-09.storage_retain.md - originally planned "auto-restart"
# feature but implementation was removed due to invalid Kubernetes spec.
# TODO: Consider implementing proper restart trigger if auto-reload proves unreliable.
