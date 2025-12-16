# Deploy Traefik HelmChartConfig to k3s auto-deploy directory
# This enables 'allowCrossNamespace' for Traefik middleware

resource "null_resource" "traefik_config" {
  triggers = {
    host = var.vps_host
    config_content = sha256(local.traefik_config_yaml)
  }

  connection {
    type        = "ssh"
    host        = var.vps_host
    user        = var.vps_user
    port        = var.ssh_port
    private_key = var.ssh_private_key
    agent       = false
    timeout     = "5m"
  }

  provisioner "file" {
    content     = local.traefik_config_yaml
    destination = "/tmp/traefik-config.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /var/lib/rancher/k3s/server/manifests",
      "sudo mv /tmp/traefik-config.yaml /var/lib/rancher/k3s/server/manifests/traefik-config.yaml",
      # Wait a bit for k3s to pick it up? Not strictly necessary as it's eventually consistent
    ]
  }

  depends_on = [
    null_resource.k3s_server
  ]
}

locals {
  traefik_config_yaml = <<-EOT
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    providers:
      kubernetesCRD:
        allowCrossNamespace: true
  EOT
}
