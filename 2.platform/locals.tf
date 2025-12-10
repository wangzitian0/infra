locals {
  internal_domain = var.internal_domain != "" ? var.internal_domain : var.base_domain
}
