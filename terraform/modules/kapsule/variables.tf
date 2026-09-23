variable "name" { type = string }
variable "tags" { type = list(string) }
variable "k8s_version" { type = string }
variable "node_type" { type = string }
variable "node_count" { type = number }
variable "private_network_id" { type = string }
