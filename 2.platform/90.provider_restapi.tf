# RestAPI Provider Configuration for Casdoor
# Documentation: https://registry.terraform.io/providers/mastercard/restapi/latest/docs

provider "restapi" {
  uri = "https://${local.casdoor_domain}"

  # Use M2M credentials (admin access)
  username = "casdoor-builtin-app"
  password = var.casdoor_admin_password

  # Casdoor API behavior configuration
  write_returns_object  = false
  create_returns_object = false
  debug                 = true
}
