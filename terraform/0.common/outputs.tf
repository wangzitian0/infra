output "api_endpoint" {
  description = "Public endpoint used by the kubeconfig"
  value       = local.api_endpoint
}

output "kubeconfig_path" {
  description = "Local path where the kubeconfig is saved after apply"
  value       = local.kubeconfig_path
}
