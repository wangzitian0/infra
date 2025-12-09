# Phase 0.0: k3s cluster bootstrap
# This file deploys k3s to VPS via SSH provisioner

locals {
  k3s_api_endpoint      = coalesce(var.api_endpoint, var.vps_host)
  k3s_disable_flags     = length(var.disable_components) > 0 ? join(" ", [for c in var.disable_components : "--disable ${c}"]) : ""
  k3s_effective_version = var.k3s_version != "" ? var.k3s_version : var.k3s_channel
  k3s_install_script = templatefile("${path.module}/scripts/install-k3s.sh.tmpl", {
    api_endpoint      = local.k3s_api_endpoint
    cluster_name      = var.cluster_name
    k3s_channel       = var.k3s_channel
    k3s_version       = var.k3s_version
    effective_version = local.k3s_effective_version
    disable_flags     = local.k3s_disable_flags
  })
}

resource "local_sensitive_file" "ssh_key" {
  content         = var.ssh_private_key
  filename        = "/tmp/infra-k3s.id_rsa"
  file_permission = "0600"
}

resource "null_resource" "k3s_server" {
  triggers = {
    host          = var.vps_host
    user          = var.vps_user
    ssh_port      = var.ssh_port
    cluster_name  = var.cluster_name
    k3s_channel   = var.k3s_channel
    k3s_version   = var.k3s_version
    disable_flags = local.k3s_disable_flags
    api_endpoint  = local.k3s_api_endpoint
    install_sha1  = sha1(local.k3s_install_script)
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
    content     = local.k3s_install_script
    destination = "/tmp/install-k3s.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod +x /tmp/install-k3s.sh",
      "sudo /tmp/install-k3s.sh"
    ]
  }
}

resource "null_resource" "kubeconfig" {
  depends_on = [
    null_resource.k3s_server,
    local_sensitive_file.ssh_key,
  ]

  triggers = {
    cluster      = null_resource.k3s_server.id
    api_endpoint = local.k3s_api_endpoint
    host         = var.vps_host
    ssh_port     = var.ssh_port
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      mkdir -p "${path.module}/output"

      ssh -i "${local_sensitive_file.ssh_key.filename}" -p "${var.ssh_port}" -o StrictHostKeyChecking=no "${var.vps_user}@${var.vps_host}" "sudo cat /etc/rancher/k3s/k3s.yaml" > "${var.kubeconfig_path}"
      chmod 600 "${var.kubeconfig_path}"
      sed -i'' -e "s/127.0.0.1/${local.k3s_api_endpoint}/g" "${var.kubeconfig_path}"
    EOT
  }
}
