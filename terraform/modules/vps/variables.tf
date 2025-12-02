variable "environment" {
  description = "Environment name"
  type        = string
}

variable "project_name" {
  description = "Project name"
  type        = string
}

variable "instance_name" {
  description = "Instance name"
  type        = string
}

variable "size" {
  description = "Instance size/type"
  type        = string
}

variable "region" {
  description = "Region/location"
  type        = string
}

variable "image" {
  description = "OS image"
  type        = string
  default     = "ubuntu-22-04-x64"
}

variable "ssh_keys" {
  description = "SSH key IDs or fingerprints"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable "allowed_ssh_ips" {
  description = "IP addresses allowed to SSH"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
