variable "kubeconfig_path" {}
variable "domain_prefix" {}
variable "base_domain" {}
variable "infisical_chart_version" {}
variable "infisical_image_tag" {}
variable "infisical_postgres_password" {}
variable "infisical_postgres_storage" {}
variable "namespaces" {
  type = map(string)
}
