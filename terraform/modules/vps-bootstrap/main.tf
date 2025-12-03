# VPS Bootstrap Module
# Automates Docker & Dokploy installation via SSH

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

variable "vps_ip" {
  description = "VPS IP address"
  type        = string
}

variable "ssh_user" {
  description = "SSH user"
  type        = string
  default     = "prod"
}

variable "ssh_private_key" {
  description = "SSH private key content"
  type        = string
  sensitive   = true
}

# Bootstrap VPS with Docker and Dokploy
resource "null_resource" "vps_bootstrap" {
  triggers = {
    vps_ip = var.vps_ip
  }

  connection {
    type        = "ssh"
    host        = var.vps_ip
    user        = var.ssh_user
    private_key = var.ssh_private_key
  }

  # Install Docker
  provisioner "remote-exec" {
    inline = [
      "echo '=== Installing Docker ==='",
      "curl -fsSL https://get.docker.com -o /tmp/get-docker.sh",
      "sudo sh /tmp/get-docker.sh",
      "sudo usermod -aG docker ${var.ssh_user}",
      "rm /tmp/get-docker.sh",
    ]
  }

  # Install Dokploy
  provisioner "remote-exec" {
    inline = [
      "echo '=== Installing Dokploy ==='",
      "curl -sSL https://dokploy.com/install.sh | sudo sh",
    ]
  }

  # Configure UFW firewall
  provisioner "remote-exec" {
    inline = [
      "echo '=== Configuring UFW ==='",
      "sudo apt-get update",
      "sudo apt-get install -y ufw",
      "sudo ufw default deny incoming",
      "sudo ufw default allow outgoing",
      "sudo ufw allow ssh",
      "sudo ufw allow 80/tcp",
      "sudo ufw allow 443/tcp",
      "echo 'y' | sudo ufw enable",
    ]
  }

  # Install fail2ban
  provisioner "remote-exec" {
    inline = [
      "echo '=== Installing fail2ban ==='",
      "sudo apt-get install -y fail2ban",
      "sudo systemctl enable fail2ban",
      "sudo systemctl start fail2ban",
    ]
  }

  # Verify installations
  provisioner "remote-exec" {
    inline = [
      "echo '=== Verification ==='",
      "docker --version",
      "docker compose version",
      "sudo ufw status",
      "sudo fail2ban-client status",
      "echo '=== Bootstrap Complete ==='",
    ]
  }
}

output "bootstrap_status" {
  description = "VPS bootstrap completion status"
  value       = "VPS ${var.vps_ip} bootstrapped successfully"
}
