# Staging Deployment - All phases in ./phases/*.tf
#
# Phase 0.0: k3s cluster bootstrap
# Phase 0.1: Infisical (Secrets Management with embedded MongoDB/Redis)
# Phase 0.2: Kubernetes Dashboard
# Phase 1.1: PostgreSQL (Shared database for applications)
# Phase 2.x: Application databases (Redis, Neo4j - using secrets from Infisical)
# Phase 3.x: Platform services (Kubero, Kubero UI)
# Phase 4.x: Observability (SigNoz, PostHog)
#
# Deploy order (for manual/staged deployment):
#   terraform apply -target="null_resource.k3s_server" -var-file="staging.tfvars"               # Phase 0.0: k3s
#   terraform apply -target="helm_release.infisical" -var-file="staging.tfvars"                 # Phase 0.1: Infisical
#   terraform apply -target="helm_release.kubernetes_dashboard" -var-file="staging.tfvars"      # Phase 0.2: Dashboard
#   terraform apply -target="kubernetes_namespace.iac" -var-file="staging.tfvars"               # Phase 1.1: namespace
#   terraform apply -target="helm_release.postgresql" -var-file="staging.tfvars"                # Phase 1.1: PostgreSQL
#
# Upcoming phases (will use Infisical for secret management):
#   terraform apply -target="helm_release.redis" -var-file="staging.tfvars"                     # Phase 2.1 (Redis)
#   terraform apply -target="helm_release.neo4j" -var-file="staging.tfvars"                     # Phase 2.2 (Neo4j)
#   terraform apply -target="helm_release.kubero" -var-file="staging.tfvars"                    # Phase 3.1 (Kubero)
#   terraform apply -target="helm_release.kubero_ui" -var-file="staging.tfvars"                 # Phase 3.2 (Kubero UI)
#   terraform apply -target="helm_release.signoz" -var-file="staging.tfvars"                    # Phase 4.1 (SigNoz)
#   terraform apply -target="helm_release.posthog" -var-file="staging.tfvars"                   # Phase 4.2 (PostHog)
#
# For full deployment: terraform apply -var-file="staging.tfvars"
#
# All phase resources are defined in ./phases/
