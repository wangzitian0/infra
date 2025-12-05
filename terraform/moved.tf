# Migration from monolithic 'module.phases' to layered architecture (1.nodep, 2.env_and_networking, 3.computing)

# L1: Bootstrap (K3s)
moved {
  from = module.phases.null_resource.k3s_server
  to   = module.nodep.null_resource.k3s_server
}

moved {
  from = module.phases.null_resource.kubeconfig
  to   = module.nodep.null_resource.kubeconfig
}

moved {
  from = module.phases.local_sensitive_file.ssh_key
  to   = module.nodep.local_sensitive_file.ssh_key
}

# L2: Environment & Networking (Secrets/Infisical/Postgres)
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

# L3: Computing (Dashboard)
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
