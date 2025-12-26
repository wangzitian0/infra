# Migration History for Platform layer
# ============================================================
# This file contains `moved` blocks that track Terraform state migrations.
# These blocks are REQUIRED to maintain state continuity across refactoring.
# Removing them may cause Terraform to treat resources as new (data loss risk).
#
# Phase 1: security → platform namespace rename
# Phase 2: kubernetes-dashboard namespace merged into platform
# Phase 3: File reorganization with semantic numbering (2025-12-26)
# ============================================================

# ============================================================
# Phase 1: security → platform (namespace and resource renames)
# ============================================================

# Note: This moved block is no longer needed since platform namespace
# is now created in Bootstrap (bootstrap/5.platform_pg.tf) as a NEW resource.
# The old namespace resource in Platform layer is replaced by a data source.
#
# moved {
#   from = kubernetes_namespace.security
#   to   = kubernetes_namespace.platform
# }

# CRITICAL: kubernetes_namespace.platform is now managed by Bootstrap (bootstrap/5.platform_pg.tf)
# The resource is removed from L2 state via Digger workflow step:
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

# ============================================================
# Phase 3: File reorganization with semantic numbering
# Renamed files (2025-12-26):
#   2.vault.tf → 01.vault.tf
#   5.casdoor.tf → 02.casdoor.tf
#   6.vault-database.tf → 03.vault-database.tf
#   7.vault-secrets-operator.tf → 04.vault-secrets-operator.tf
#   3.dashboard.tf → 20.kubernetes-dashboard.tf
#   4.portal.tf → 21.portal.tf
#   10.kubero.tf → 22.kubero.tf
#   11.signoz.tf → 23.signoz.tf
#   90.casdoor-apps.tf → 80.casdoor-apps.tf
#   91.casdoor-roles.tf → 81.casdoor-roles.tf
#   90.provider_restapi.tf → 82.provider-restapi.tf
#   91.vault-auth-kubernetes.tf → 90.vault-auth-kubernetes.tf
#   91.vault-policy-default.tf → 92.vault-policy-default.tf
#   92.portal-auth.tf → 93.portal-auth.tf
#   92.vault-kubero.tf → 94.vault-kubero.tf
# ============================================================
# NOTE: No moved blocks required for file renames!
# Files were renamed via `git mv`, which preserves Git history.
# Terraform state remains unchanged because resource addresses did not change.
# Only the physical file path changed, not the resource identifiers.
