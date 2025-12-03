variable "vps_ip" {}
variable "ssh_user" {}
variable "ssh_private_key" {
  sensitive = true
}
