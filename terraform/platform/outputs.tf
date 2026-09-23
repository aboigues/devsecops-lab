output "gitlab_url" {
  value = module.gitlab.url
}

output "registry_host" {
  value = module.gitlab.registry_host
}

output "gitlab_public_ip" {
  value = module.gitlab.public_ip
}

output "gitlab_root_password_secret_id" {
  description = "scw secret version access <id> revision=latest --profile ... pour lire le mot de passe root"
  value       = scaleway_secret.gitlab_root.id
}

output "gitlab_terraform_token" {
  value     = "glpat-${random_password.terraform_token.result}"
  sensitive = true
}

output "kubeconfig" {
  value     = module.kapsule.kubeconfig
  sensitive = true
}

output "kapsule_cluster_id" {
  value = module.kapsule.cluster_id
}
