output "public_ip" {
  value = scaleway_instance_ip.runner.address
}
