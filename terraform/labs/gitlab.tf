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

  # Garde-fous de fusion (tous disponibles en édition CE) : pipeline vert obligatoire, un pipeline
  # ignoré ([skip ci]) ne compte pas comme un succès, discussions résolues, historique linéaire
  only_allow_merge_if_pipeline_succeeds            = true
  allow_merge_on_skipped_pipeline                  = false
  only_allow_merge_if_all_discussions_are_resolved = true
  merge_method                                     = "ff"
  remove_source_branch_after_merge                 = true
  container_registry_access_level                  = "private"

  depends_on = [gitlab_application_settings.this]
}

# `main` n'accepte aucun push direct, pas même d'un administrateur ni du bot GitOps :
# tout changement arrive par merge request, fusionnée par un humain (l'apprenant, mainteneur).
resource "gitlab_branch_protection" "main" {
  for_each           = var.learners
  project            = gitlab_project.learner[each.key].id
  branch             = "main"
  push_access_level  = "no one"
  merge_access_level = "maintainer"
  allow_force_push   = false
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

# Le bot GitOps pousse une branche `gitops/<sha>` et ouvre une merge request ; il ne peut pas fusionner
# (niveau developer < maintainer requis sur `main`). La promotion reste une décision humaine.
resource "gitlab_project_access_token" "gitops" {
  for_each     = var.learners
  project      = gitlab_project.learner[each.key].id
  name         = "gitops-bot"
  scopes       = ["write_repository"]
  access_level = "developer"

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
