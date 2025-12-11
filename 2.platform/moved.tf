# Migration History for L2 Platform
# ============================================================
# This file contains `moved` blocks that track Terraform state migrations.
# These blocks are REQUIRED to maintain state continuity across refactoring.
# Removing them may cause Terraform to treat resources as new (data loss risk).
#
# Phase 1: security → platform namespace rename
# Phase 2: kubernetes-dashboard namespace merged into platform
# ============================================================

# ============================================================
# Phase 1: security → platform (namespace and resource renames)
# ============================================================

# Note: This moved block is no longer needed since platform namespace
# is now created in L1 (1.bootstrap/5.platform_pg.tf) as a NEW resource.
# The old namespace resource in L2 is replaced by a data source.
#
# moved {
#   from = kubernetes_namespace.security
#   to   = kubernetes_namespace.platform
# }

# CRITICAL: Tell Terraform to forget kubernetes_namespace.platform from L2 state
# without destroying it. The resource is now managed by L1.
removed {
  from = kubernetes_namespace.platform
  lifecycle {
    destroy = false
  }
}

# ============================================================
# Phase 2: kubernetes-dashboard → platform (namespace merge)
# Dashboard resources moved to platform namespace
# ============================================================

# Note: kubernetes_namespace.dashboard is DELETED, not moved
# Resources in dashboard namespace will be recreated in platform namespace
# This is intentional as Dashboard is stateless
