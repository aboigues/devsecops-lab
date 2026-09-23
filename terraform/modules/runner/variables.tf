variable "name" { type = string }
variable "tags" { type = list(string) }
variable "instance_type" { type = string }
variable "runner_version" { type = string }
variable "concurrency" { type = number }
variable "admin_cidrs" { type = list(string) }
variable "private_network_id" { type = string }
variable "gitlab_url" { type = string }

variable "runner_token" {
  type        = string
  sensitive   = true
  description = "PAT à scope create_runner : permet d'enregistrer le runner, rien d'autre"
}
