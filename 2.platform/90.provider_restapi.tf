# RestAPI Provider Configuration for Casdoor
# Documentation: https://registry.terraform.io/providers/mastercard/restapi/latest/docs

# Read casdoor-builtin-app client secret from K8s secret
data "kubernetes_secret" "casdoor_builtin" {
  metadata {
    name      = "casdoor-builtin-secret"
    namespace = data.kubernetes_namespace.platform.metadata[0].name
  }
}

provider "restapi" {
  uri = "https://${local.casdoor_domain}"

  # Use M2M credentials from casdoor-builtin-app
  username = "casdoor-builtin-app"
  password = data.kubernetes_secret.casdoor_builtin.data["client-secret"]

  # Casdoor API behavior configuration
  write_returns_object  = false
  create_returns_object = false
  debug                 = true
}
