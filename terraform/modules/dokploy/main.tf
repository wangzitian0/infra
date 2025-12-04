locals {
  compose_file_path = var.compose_file != "" ? var.compose_file : "${path.module}/../../compose/platform/infisical.yml"
  app_name          = var.compose_app_name != "" ? var.compose_app_name : "${var.compose_name}-${var.environment_name}"
}

resource "null_resource" "dokploy_infisical" {
  count = var.enable_infisical ? 1 : 0

  triggers = {
    template_hash        = filesha256(local.compose_file_path)
    force_redeploy_token = var.force_redeploy_token
  }

  provisioner "local-exec" {
    command     = "${path.module}/../../scripts/dokploy/bootstrap_infisical.sh"
    working_dir = "${path.module}/../.."
    environment = {
      DOKPLOY_API_URL          = var.api_url
      DOKPLOY_API_KEY          = var.api_key
      DOKPLOY_ORGANIZATION_ID  = var.organization_id
      DOKPLOY_PROJECT_NAME     = var.project_name
      DOKPLOY_ENVIRONMENT_NAME = var.environment_name
      DOKPLOY_COMPOSE_NAME     = var.compose_name
      DOKPLOY_COMPOSE_APP_NAME = local.app_name
      DOKPLOY_COMPOSE_FILE     = local.compose_file_path
      DOKPLOY_SSH_KEY_NAME     = var.ssh_key_name
      DOKPLOY_SERVER_NAME      = var.server_name
      DOKPLOY_SERVER_IP        = var.server_ip
      DOKPLOY_SERVER_USERNAME  = var.server_username
      DOKPLOY_SERVER_PORT      = tostring(var.server_port)
      DOKPLOY_SERVER_TYPE      = var.server_type
      DOKPLOY_SSH_PRIVATE_KEY  = var.ssh_private_key
      DOKPLOY_SSH_PUBLIC_KEY   = var.ssh_public_key

      INFISICAL_HOST             = var.infisical_host
      INFISICAL_ENCRYPTION_KEY   = var.infisical_encryption_key
      INFISICAL_ADMIN_EMAIL      = var.infisical_admin_email
      INFISICAL_ADMIN_PASSWORD   = var.infisical_admin_password
      INFISICAL_LICENSE_KEY      = var.infisical_license_key
      INFISICAL_POSTGRES_USER    = var.infisical_postgres_user
      INFISICAL_POSTGRES_PASSWORD= var.infisical_postgres_password
      INFISICAL_POSTGRES_DB      = var.infisical_postgres_db
      INFISICAL_REDIS_PASSWORD   = var.infisical_redis_password
      INFISICAL_TRAEFIK_NETWORK  = var.infisical_traefik_network
      DOKPLOY_FORCE_DEPLOY       = "1"
    }
  }
}
