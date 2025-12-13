# State cleanup blocks for L2 Platform.
#
# Use declarative `removed` blocks instead of imperative `terraform state rm` hooks
# in Atlantis workflows. This prevents "plan modifies state" side effects and avoids
# stale plan/apply mismatches.

removed {
  from = kubernetes_namespace.platform

  lifecycle {
    destroy = false
  }
}
