# Staging Deployment - All phases in ./phases/*.tf
#
# Phase 0.x: k3s + platform PostgreSQL (for Infisical/Kubero) + Infisical
# Phase 1.x: Kubernetes Dashboard + Kubero + Kubero UI + application PostgreSQL
# Phase 2.x: Data services (Neo4j, Redis, ClickHouse)
# Phase 3.x: Observability (SigNoz, PostHog)
#
# Deploy order (for manual/staged deployment):
#   terraform apply -target="null_resource.k3s_server"                    # Phase 0.x: k3s
#   terraform apply -target="module.phases.helm_release.postgresql"       # Phase 0.x: platform PG
#   terraform apply -target="module.phases.helm_release.infisical"        # Phase 0.x: Infisical
#   terraform apply -target="module.phases.helm_release.kubernetes_dashboard"  # Phase 1.x: Dashboard
#
# For full deployment: terraform apply

# Load all phase resources from ./phases/ directory
module "phases" {
  source = "./phases"

  kubeconfig_path             = local.kubeconfig_path
  namespaces                  = local.namespaces
  domains                     = local.domains
  infisical_postgres_password = var.infisical_postgres_password
  infisical_postgres_storage  = var.infisical_postgres_storage
  redis_password              = var.redis_password
  redis_storage               = var.redis_storage
  neo4j_password              = var.neo4j_password
  neo4j_storage               = var.neo4j_storage
  enable_observability        = var.enable_observability
  infisical_chart_version     = var.infisical_chart_version
  infisical_image_tag         = var.infisical_image_tag
}
