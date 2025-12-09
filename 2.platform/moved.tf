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

moved {
  from = kubernetes_namespace.security
  to   = kubernetes_namespace.platform
}

# ============================================================
# Phase 2: kubernetes-dashboard → platform (namespace merge)
# Dashboard resources moved to platform namespace
# ============================================================

# Note: kubernetes_namespace.dashboard is DELETED, not moved
# Resources in dashboard namespace will be recreated in platform namespace
# This is intentional as Dashboard is stateless
