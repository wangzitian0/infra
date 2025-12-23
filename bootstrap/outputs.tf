output "api_endpoint" {
  description = "Public endpoint used by the kubeconfig"
  value       = local.api_endpoint
}

output "kubeconfig_path" {
  description = "Local path where the kubeconfig is saved after apply"
  value       = local.kubeconfig_path
}

data "local_file" "kubeconfig" {
  filename   = local.kubeconfig_path
  depends_on = [null_resource.kubeconfig]
}

output "kubeconfig" {
  description = "Kubeconfig content for L2"
  value       = data.local_file.kubeconfig.content
  sensitive   = true
}

output "r2_bucket" {
  description = "R2 Bucket Name"
  value       = var.r2_bucket
}

output "r2_account_id" {
  description = "R2 Account ID"
  value       = var.r2_account_id
}
