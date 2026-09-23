output "url" {
  value = "https://${local.host}"
}

output "registry_host" {
  value = local.registry_host
}

output "public_ip" {
  value = scaleway_instance_ip.gitlab.address
}
