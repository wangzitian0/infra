locals {
  infisical_repo_url       = "https://dl.cloudsmith.io/public/infisical/helm-charts/helm/charts/"
  infisical_chart_name     = "infisical/infisical"
  infisical_remote_values  = "/tmp/infisical-values.yaml"
  infisical_site_url       = trimspace(var.infisical_site_url) != "" ? var.infisical_site_url : "http://infisical.local"
  infisical_smtp_from_name = "Infisical"
  infisical_smtp_from      = "noreply@infisical.local"

  infisical_values = templatefile("${path.module}/scripts/infisical-values.yaml.tmpl", {
    backend_image_tag     = var.infisical_image_tag
    encryption_key        = random_id.infisical_keys["encryption"].hex
    jwt_signup_secret     = random_id.infisical_keys["jwt_signup"].hex
    jwt_refresh_secret    = random_id.infisical_keys["jwt_refresh"].hex
    jwt_auth_secret       = random_id.infisical_keys["jwt_auth"].hex
    jwt_service_secret    = random_id.infisical_keys["jwt_service"].hex
    jwt_mfa_secret        = random_id.infisical_keys["jwt_mfa"].hex
    jwt_provider_secret   = random_id.infisical_keys["jwt_provider"].hex
    site_url              = local.infisical_site_url
    smtp_from_address     = local.infisical_smtp_from
    smtp_from_name        = local.infisical_smtp_from_name
    smtp_host             = "mailhog"
    smtp_port             = 1025
    smtp_secure           = false
    smtp_username         = local.infisical_smtp_from
    smtp_password         = ""
    invite_only_signup    = false
    redis_url             = "redis://redis-master:6379"
    mongodb_user_password = random_password.infisical_mongodb_user.result
    mongodb_root_password = random_password.infisical_mongodb_root.result
    mailhog_enabled       = true
  })
}

resource "random_id" "infisical_keys" {
  for_each    = toset(["encryption", "jwt_signup", "jwt_refresh", "jwt_auth", "jwt_service", "jwt_mfa", "jwt_provider"])
  byte_length = 16
}

resource "random_password" "infisical_mongodb_user" {
  length  = 16
  special = false
}

resource "random_password" "infisical_mongodb_root" {
  length  = 20
  special = false
}

# Install Infisical via Helm after k3s is ready.
resource "null_resource" "infisical" {
  depends_on = [
    null_resource.kubeconfig,
  ]

  triggers = {
    cluster_id      = null_resource.k3s_server.id
    namespace       = var.infisical_namespace
    chart_version   = var.infisical_chart_version
    values_checksum = sha1(nonsensitive(local.infisical_values))
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
    content     = nonsensitive(local.infisical_values)
    destination = local.infisical_remote_values
  }

  provisioner "remote-exec" {
    inline = [<<-EOT
      set -euo pipefail
      trap 'sudo rm -f ${local.infisical_remote_values}' EXIT
      HELM_BIN="$(command -v helm || true)"
      if [ -z "$HELM_BIN" ]; then
        curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | sudo bash
        HELM_BIN="/usr/local/bin/helm"
      fi

      sudo env KUBECONFIG=/etc/rancher/k3s/k3s.yaml "$HELM_BIN" repo add infisical "${local.infisical_repo_url}"
      sudo env KUBECONFIG=/etc/rancher/k3s/k3s.yaml "$HELM_BIN" repo update
      sudo env KUBECONFIG=/etc/rancher/k3s/k3s.yaml "$HELM_BIN" upgrade --install infisical ${local.infisical_chart_name} \
        --version ${var.infisical_chart_version} \
        --namespace ${var.infisical_namespace} \
        --create-namespace \
        --atomic \
        --timeout 15m \
        --values ${local.infisical_remote_values}

      sudo rm -f ${local.infisical_remote_values}
    EOT
    ]
  }
}
