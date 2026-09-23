resource "gitlab_application_settings" "this" {
  # Autorise l'import depuis une URL git (projets apprenants créés depuis le dépôt modèle)
  import_sources                          = ["git"]
  signup_enabled                          = false
  password_authentication_enabled_for_git = true
}

resource "gitlab_group" "lab" {
  name             = "DevSecOps Lab"
  path             = "devsecops-lab"
  visibility_level = "private"
}

resource "random_password" "learner" {
  for_each = var.learners
  length   = 20
  special  = false
}

resource "gitlab_user" "learner" {
  for_each          = var.learners
  name              = each.key
  username          = each.key
  email             = "${each.key}@lab.invalid"
  password          = random_password.learner[each.key].result
  skip_confirmation = true
  can_create_group  = false
  projects_limit    = 0
}

resource "gitlab_project" "learner" {
  for_each         = var.learners
  name             = "bank-api-${each.key}"
  namespace_id     = gitlab_group.lab.id
  import_url       = var.source_repo_url
  visibility_level = "private"

  # Garde-fous : on ne fusionne pas sans pipeline vert
  only_allow_merge_if_pipeline_succeeds = true
  container_registry_access_level       = "private"

  depends_on = [gitlab_application_settings.this]
}

resource "gitlab_project_membership" "learner" {
  for_each     = var.learners
  project      = gitlab_project.learner[each.key].id
  user_id      = gitlab_user.learner[each.key].id
  access_level = "maintainer"
}

# Lecture seule, dédiée à Argo CD (dépôt) et aux noeuds Kubernetes (registry)
resource "gitlab_project_deploy_token" "argocd" {
  for_each = var.learners
  project  = gitlab_project.learner[each.key].id
  name     = "argocd"
  scopes   = ["read_repository", "read_registry"]
}

# Écriture limitée au dépôt : la CI met à jour le tag d'image dans gitops/ (pull-based GitOps)
resource "gitlab_project_access_token" "gitops" {
  for_each     = var.learners
  project      = gitlab_project.learner[each.key].id
  name         = "gitops-bot"
  scopes       = ["write_repository"]
  access_level = "maintainer"

  rotation_configuration = {
    expiration_days    = 30
    rotate_before_days = 7
  }
}

resource "gitlab_project_variable" "gitops_token" {
  for_each  = var.learners
  project   = gitlab_project.learner[each.key].id
  key       = "GITOPS_TOKEN"
  value     = gitlab_project_access_token.gitops[each.key].token
  masked    = true
  protected = true
}
