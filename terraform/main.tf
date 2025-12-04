terraform {
  required_version = ">= 1.6.0"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

locals {
  api_endpoint      = coalesce(var.api_endpoint, var.vps_host)
  disable_flags     = length(var.disable_components) > 0 ? join(" ", [for c in var.disable_components : "--disable ${c}"]) : ""
  effective_version = var.k3s_version != "" ? var.k3s_version : var.k3s_channel
  install_script = templatefile("${path.module}/scripts/install-k3s.sh.tmpl", {
    api_endpoint      = local.api_endpoint
    cluster_name      = var.cluster_name
    k3s_channel       = var.k3s_channel
    k3s_version       = var.k3s_version
    effective_version = local.effective_version
    disable_flags     = local.disable_flags
  })
  kubeconfig_path = "${path.module}/output/${var.cluster_name}-kubeconfig.yaml"
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
    disable_flags = local.disable_flags
    api_endpoint  = local.api_endpoint
    install_sha1  = sha1(local.install_script)
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
    content     = local.install_script
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
    api_endpoint = local.api_endpoint
    host         = var.vps_host
    ssh_port     = var.ssh_port
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      mkdir -p "${path.module}/output"

      ssh -i "${local_sensitive_file.ssh_key.filename}" -p "${var.ssh_port}" -o StrictHostKeyChecking=no "${var.vps_user}@${var.vps_host}" "sudo cat /etc/rancher/k3s/k3s.yaml" > "${local.kubeconfig_path}"
      chmod 600 "${local.kubeconfig_path}"
      sed -i'' -e "s/127.0.0.1/${local.api_endpoint}/g" "${local.kubeconfig_path}"
    EOT
  }
}
