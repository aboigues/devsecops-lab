variable "state_bucket" { type = string }

variable "state_access_key" {
  type      = string
  sensitive = true
}

variable "state_secret_key" {
  type      = string
  sensitive = true
}

variable "source_repo_url" {
  type        = string
  default     = "https://github.com/aboigues/devsecops-lab.git"
  description = "Dépôt public importé dans chaque projet apprenant (code + pipeline + manifestes GitOps)"
}

variable "learners" {
  type        = set(string)
  description = "Identifiants des apprenants : un utilisateur, un projet, un namespace et une application Argo CD chacun"

  validation {
    condition     = alltrue([for l in var.learners : can(regex("^[a-z][a-z0-9-]{1,20}$", l))])
    error_message = "Identifiants en minuscules, chiffres et tirets (compatibles DNS Kubernetes)."
  }
}

variable "argocd_chart_version" {
  type    = string
  default = "10.9.2"
}

variable "argocd_apps_chart_version" {
  type    = string
  default = "2.0.5"
}
