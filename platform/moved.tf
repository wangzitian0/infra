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

# CRITICAL: kubernetes_namespace.platform is now managed by L1 (1.bootstrap/5.platform_pg.tf)
# The resource is removed from L2 state via atlantis.yaml workflow step:
#   terraform state rm kubernetes_namespace.platform
# This runs automatically before plan/apply to prevent namespace destruction.
# See PR #125 for migration details.

# ============================================================
# Phase 2: kubernetes-dashboard → platform (namespace merge)
# Dashboard resources moved to platform namespace
# ============================================================

# Note: kubernetes_namespace.dashboard is DELETED, not moved
# Resources in dashboard namespace will be recreated in platform namespace
# This is intentional as Dashboard is stateless
