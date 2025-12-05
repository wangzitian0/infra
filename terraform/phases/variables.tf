# Phases share these common variables (inherited from parent)
# These are placeholders - actual values come from ../variables.tf via module inputs

variable "kubeconfig_path" {
  type = string
}

variable "namespaces" {
  type = map(string)
}

variable "domains" {
  type = map(string)
}

variable "infisical_postgres_password" {
  type      = string
  sensitive = true
}

variable "redis_password" {
  type      = string
  sensitive = true
}

variable "neo4j_password" {
  type      = string
  sensitive = true
}

variable "infisical_postgres_storage" {
  type = string
}

variable "redis_storage" {
  type = string
}

variable "neo4j_storage" {
  type = string
}

variable "enable_observability" {
  type = bool
}

variable "infisical_chart_version" {
  type = string
}

variable "infisical_image_tag" {
  type = string
}
