# VPS Module - Template for multiple providers
#
# This module provides a unified interface for VPS provisioning.
# Uncomment and configure the provider block you're using.

# Example: DigitalOcean Droplet
# resource "digitalocean_droplet" "instance" {
#   name   = var.instance_name
#   size   = var.size
#   image  = var.image
#   region = var.region
#   ssh_keys = var.ssh_keys
#   tags = [for k, v in var.tags : "${k}:${v}"]
#
#   user_data = templatefile("${path.module}/cloud-init.yaml", {
#     environment  = var.environment
#     project_name = var.project_name
#   })
# }

# Example: Hetzner Cloud Server
# resource "hcloud_server" "instance" {
#   name        = var.instance_name
#   server_type = var.size
#   image       = var.image
#   location    = var.region
#   ssh_keys    = var.ssh_keys
#   labels      = var.tags
#
#   user_data = templatefile("${path.module}/cloud-init.yaml", {
#     environment  = var.environment
#     project_name = var.project_name
#   })
# }

# Placeholder resource for development
# Remove this when using actual provider
resource "null_resource" "vps_placeholder" {
  triggers = {
    instance_name = var.instance_name
  }

  provisioner "local-exec" {
    command = "echo 'VPS Module: ${var.instance_name} would be created here'"
  }
}

# Firewall rules (example for DigitalOcean)
# resource "digitalocean_firewall" "web" {
#   name = "${var.project_name}-${var.environment}-firewall"
#
#   droplet_ids = [digitalocean_droplet.instance.id]
#
#   inbound_rule {
#     protocol         = "tcp"
#     port_range       = "22"
#     source_addresses = var.allowed_ssh_ips
#   }
#
#   inbound_rule {
#     protocol         = "tcp"
#     port_range       = "80"
#     source_addresses = ["0.0.0.0/0", "::/0"]
#   }
#
#   inbound_rule {
#     protocol         = "tcp"
#     port_range       = "443"
#     source_addresses = ["0.0.0.0/0", "::/0"]
#   }
#
#   outbound_rule {
#     protocol              = "tcp"
#     port_range            = "1-65535"
#     destination_addresses = ["0.0.0.0/0", "::/0"]
#   }
#
#   outbound_rule {
#     protocol              = "udp"
#     port_range            = "1-65535"
#     destination_addresses = ["0.0.0.0/0", "::/0"]
#   }
# }
