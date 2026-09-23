output "learner_credentials" {
  description = "terraform output -json learner_credentials : identifiants à remettre aux apprenants"
  sensitive   = true
  value = {
    for l in var.learners : l => {
      username = gitlab_user.learner[l].username
      password = random_password.learner[l].result
      project  = gitlab_project.learner[l].web_url
    }
  }
}
