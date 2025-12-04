# Staging Deployment - All phases in ./phases/*.tf
#
# Deploy in order using -target:
#   terraform apply -target="null_resource.k3s_server" -var-file="staging.tfvars"        # Phase 0
#   terraform apply -target="kubernetes_namespace.iac" -var-file="staging.tfvars"        # Phase 1.1 setup
#   terraform apply -target="helm_release.postgresql" -var-file="staging.tfvars"        # Phase 1.1
#   terraform apply -target="helm_release.infisical" -var-file="staging.tfvars"         # Phase 1.2
#   terraform apply -target="helm_release.redis,helm_release.neo4j" -var-file="staging.tfvars"  # Phase 2.1
#   terraform apply -target="helm_release.kubero" -var-file="staging.tfvars"            # Phase 3.1
#   terraform apply -target="helm_release.kubero_ui" -var-file="staging.tfvars"         # Phase 3.2
#   terraform apply -target="helm_release.signoz,helm_release.posthog" -var-file="staging.tfvars"  # Phase 4

# All phases resources are defined in ./phases/
