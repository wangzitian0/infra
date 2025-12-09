# Migration History (DO NOT DELETE)
# ============================================================
# This file contains `moved` blocks that track Terraform state migrations.
# These blocks are REQUIRED to maintain state continuity across refactoring.
# Removing them may cause Terraform to treat resources as new (data loss risk).
#
# Phase 1: monolithic 'module.phases' → layered architecture (L1-L5)
# Phase 2: L1-L5 → L1-L4 (simplified 4-layer architecture)
# Phase 3: module.nodep → flat resources (directory flattening)
# ============================================================

# ============================================================
# Phase 1: module.phases → L1-L5 (historical, keep for state)
# ============================================================

# L1: Bootstrap (K3s)
moved {
  from = module.phases.null_resource.k3s_server
  to   = null_resource.k3s_server
}

moved {
  from = module.phases.null_resource.kubeconfig
  to   = null_resource.kubeconfig
}

moved {
  from = module.phases.local_sensitive_file.ssh_key
  to   = local_sensitive_file.ssh_key
}

# L2: Environment & Networking → Platform (Secrets/Infisical/Postgres)
moved {
  from = module.phases.kubernetes_namespace.iac
  to   = module.env_and_networking.kubernetes_namespace.iac
}

moved {
  from = module.phases.helm_release.postgresql
  to   = module.env_and_networking.helm_release.postgresql
}

moved {
  from = module.phases.helm_release.infisical
  to   = module.env_and_networking.helm_release.infisical
}

moved {
  from = module.phases.kubernetes_secret.infisical_secrets
  to   = module.env_and_networking.kubernetes_secret.infisical_secrets
}

# Infisical Random IDs
moved {
  from = module.phases.random_id.infisical_encryption_key
  to   = module.env_and_networking.random_id.infisical_encryption_key
}

moved {
  from = module.phases.random_id.infisical_jwt_signup_secret
  to   = module.env_and_networking.random_id.infisical_jwt_signup_secret
}

moved {
  from = module.phases.random_id.infisical_jwt_refresh_secret
  to   = module.env_and_networking.random_id.infisical_jwt_refresh_secret
}

moved {
  from = module.phases.random_id.infisical_jwt_auth_secret
  to   = module.env_and_networking.random_id.infisical_jwt_auth_secret
}

moved {
  from = module.phases.random_id.infisical_jwt_service_secret
  to   = module.env_and_networking.random_id.infisical_jwt_service_secret
}

moved {
  from = module.phases.random_id.infisical_jwt_mfa_secret
  to   = module.env_and_networking.random_id.infisical_jwt_mfa_secret
}

moved {
  from = module.phases.random_id.infisical_jwt_provider_secret
  to   = module.env_and_networking.random_id.infisical_jwt_provider_secret
}

# L3: Computing (Dashboard) - historical
moved {
  from = module.phases.kubernetes_namespace.dashboard
  to   = module.computing.kubernetes_namespace.dashboard
}

moved {
  from = module.phases.kubernetes_service_account.dashboard
  to   = module.computing.kubernetes_service_account.dashboard
}

moved {
  from = module.phases.helm_release.kubernetes_dashboard
  to   = module.computing.helm_release.kubernetes_dashboard
}

moved {
  from = module.phases.kubernetes_service_account.dashboard_admin
  to   = module.computing.kubernetes_service_account.dashboard_admin
}

moved {
  from = module.phases.kubernetes_cluster_role_binding.dashboard_admin
  to   = module.computing.kubernetes_cluster_role_binding.dashboard_admin
}

moved {
  from = module.phases.kubernetes_secret.dashboard_admin_token
  to   = module.computing.kubernetes_secret.dashboard_admin_token
}

# ============================================================
# Phase 2: L1-L5 → L1-L4 (4-layer simplification)
# ============================================================

# L2: env_and_networking → platform
moved {
  from = module.env_and_networking.kubernetes_namespace.iac
  to   = module.platform.kubernetes_namespace.iac
}

moved {
  from = module.env_and_networking.kubernetes_namespace.security
  to   = module.platform.kubernetes_namespace.security
}

moved {
  from = module.env_and_networking.helm_release.postgresql
  to   = module.platform.helm_release.postgresql
}

moved {
  from = module.env_and_networking.helm_release.infisical
  to   = module.platform.helm_release.infisical
}

moved {
  from = module.env_and_networking.kubernetes_secret.infisical_secrets
  to   = module.platform.kubernetes_secret.infisical_secrets
}

moved {
  from = module.env_and_networking.random_id.infisical_encryption_key
  to   = module.platform.random_id.infisical_encryption_key
}

moved {
  from = module.env_and_networking.random_id.infisical_jwt_signup_secret
  to   = module.platform.random_id.infisical_jwt_signup_secret
}

moved {
  from = module.env_and_networking.random_id.infisical_jwt_refresh_secret
  to   = module.platform.random_id.infisical_jwt_refresh_secret
}

moved {
  from = module.env_and_networking.random_id.infisical_jwt_auth_secret
  to   = module.platform.random_id.infisical_jwt_auth_secret
}

moved {
  from = module.env_and_networking.random_id.infisical_jwt_service_secret
  to   = module.platform.random_id.infisical_jwt_service_secret
}

moved {
  from = module.env_and_networking.random_id.infisical_jwt_mfa_secret
  to   = module.platform.random_id.infisical_jwt_mfa_secret
}

moved {
  from = module.env_and_networking.random_id.infisical_jwt_provider_secret
  to   = module.platform.random_id.infisical_jwt_provider_secret
}

# L3: computing → platform (Dashboard merged into platform)
moved {
  from = module.computing.kubernetes_namespace.dashboard
  to   = module.platform.kubernetes_namespace.dashboard
}

moved {
  from = module.computing.kubernetes_service_account.dashboard
  to   = module.platform.kubernetes_service_account.dashboard
}

moved {
  from = module.computing.helm_release.kubernetes_dashboard
  to   = module.platform.helm_release.kubernetes_dashboard
}

moved {
  from = module.computing.kubernetes_service_account.dashboard_admin
  to   = module.platform.kubernetes_service_account.dashboard_admin
}

moved {
  from = module.computing.kubernetes_cluster_role_binding.dashboard_admin
  to   = module.platform.kubernetes_cluster_role_binding.dashboard_admin
}

moved {
  from = module.computing.kubernetes_secret.dashboard_admin_token
  to   = module.platform.kubernetes_secret.dashboard_admin_token
}

# ============================================================
# Phase 4: nodep → bootstrap (namespace rename for L1 layer convention)
# ============================================================

moved {
  from = kubernetes_namespace.nodep
  to   = kubernetes_namespace.bootstrap
}
