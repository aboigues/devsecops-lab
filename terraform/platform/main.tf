locals {
  tags = [var.name, "managed-by:terraform"]
}

resource "scaleway_vpc_private_network" "lab" {
  name = "${var.name}-pn"
  tags = local.tags
}

resource "scaleway_iam_ssh_key" "admin" {
  name       = "${var.name}-admin"
  public_key = var.ssh_public_key
}

# Jetons générés par Terraform puis injectés dans GitLab au premier démarrage :
# - terraform : scope api, utilisé par l'étape « labs » (provider gitlab)
# - runner    : scope create_runner uniquement (moindre privilège), utilisé par la VM runner
resource "random_password" "gitlab_root" {
  length  = 32
  special = false
}

resource "random_password" "terraform_token" {
  length  = 40
  special = false
}

resource "random_password" "runner_token" {
  length  = 40
  special = false
}

resource "scaleway_secret" "gitlab_root" {
  name        = "${var.name}-gitlab-root-password"
  description = "Mot de passe root GitLab du lab"
  tags        = local.tags
}

resource "scaleway_secret_version" "gitlab_root" {
  secret_id = scaleway_secret.gitlab_root.id
  data      = random_password.gitlab_root.result
}

module "gitlab" {
  source = "../modules/gitlab"

  name               = var.name
  tags               = local.tags
  instance_type      = var.gitlab_instance_type
  gitlab_version     = var.gitlab_version
  admin_cidrs        = var.admin_cidrs
  private_network_id = scaleway_vpc_private_network.lab.id
  letsencrypt_email  = var.letsencrypt_email
  root_password      = random_password.gitlab_root.result
  terraform_token    = "glpat-${random_password.terraform_token.result}"
  runner_token       = "glpat-${random_password.runner_token.result}"

  depends_on = [scaleway_iam_ssh_key.admin]
}

module "runner" {
  source = "../modules/runner"

  name               = var.name
  tags               = local.tags
  instance_type      = var.runner_instance_type
  runner_version     = var.runner_version
  concurrency        = var.runner_concurrency
  admin_cidrs        = var.admin_cidrs
  private_network_id = scaleway_vpc_private_network.lab.id
  gitlab_url         = module.gitlab.url
  runner_token       = "glpat-${random_password.runner_token.result}"

  depends_on = [scaleway_iam_ssh_key.admin]
}

module "kapsule" {
  source = "../modules/kapsule"

  name               = var.name
  tags               = local.tags
  k8s_version        = var.k8s_version
  node_type          = var.k8s_node_type
  node_count         = var.k8s_node_count
  private_network_id = scaleway_vpc_private_network.lab.id
}
