# Outputs - adjust based on your provider

output "instance_id" {
  description = "VPS instance ID"
  # value       = digitalocean_droplet.instance.id
  # value       = hcloud_server.instance.id
  value       = null_resource.vps_placeholder.id
}

output "public_ip" {
  description = "Public IP address"
  # value       = digitalocean_droplet.instance.ipv4_address
  # value       = hcloud_server.instance.ipv4_address
  value       = "0.0.0.0"  # Placeholder
}

output "private_ip" {
  description = "Private IP address"
  # value       = digitalocean_droplet.instance.ipv4_address_private
  # value       = hcloud_server.instance.ipv4_address_private
  value       = null
}

output "instance_name" {
  description = "Instance name"
  value       = var.instance_name
}
