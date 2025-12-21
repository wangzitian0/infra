# Deploy Traefik HelmChartConfig via kubectl_manifest to avoid SSH file copy.
resource "kubectl_manifest" "traefik_config" {
  yaml_body = local.traefik_config_yaml

  server_side_apply = true

  depends_on = [
    null_resource.kubeconfig
  ]
}

locals {
  traefik_config_yaml = <<-EOT
apiVersion: helm.cattle.io/v1
kind: HelmChartConfig
metadata:
  name: traefik
  namespace: kube-system
spec:
  valuesContent: |-
    providers:
      kubernetesCRD:
        allowCrossNamespace: true
  EOT
}
