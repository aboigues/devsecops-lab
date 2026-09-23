variable "name" { type = string }
variable "tags" { type = list(string) }
variable "instance_type" { type = string }
variable "gitlab_version" { type = string }
variable "admin_cidrs" { type = list(string) }
variable "private_network_id" { type = string }
variable "letsencrypt_email" { type = string }

variable "root_volume_size_gb" {
  type    = number
  default = 60
}

variable "root_password" {
  type      = string
  sensitive = true
}

variable "terraform_token" {
  type      = string
  sensitive = true
}

variable "runner_token" {
  type      = string
  sensitive = true
}
