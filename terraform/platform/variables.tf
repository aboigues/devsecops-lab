variable "region" {
  type    = string
  default = "fr-par"
}

variable "zone" {
  type    = string
  default = "fr-par-1"
}

variable "name" {
  type        = string
  default     = "devsecops-lab"
  description = "Préfixe de toutes les ressources (et tag de rattachement pour le nettoyage)"
}

variable "admin_cidrs" {
  type        = list(string)
  description = "Plages autorisées en SSH (ex. IP publique du formateur en /32)"

  validation {
    condition     = alltrue([for c in var.admin_cidrs : can(cidrhost(c, 0)) && c != "0.0.0.0/0"])
    error_message = "admin_cidrs doit contenir des CIDR valides, jamais 0.0.0.0/0."
  }
}

variable "ssh_public_key" {
  type        = string
  description = "Clé publique SSH d'administration"
}

variable "letsencrypt_email" {
  type        = string
  description = "Contact Let's Encrypt pour les certificats GitLab et registry"
}

variable "gitlab_version" {
  type    = string
  default = "19.4.1-ce.0"
}

variable "gitlab_instance_type" {
  type = string
  # DEV1-XL (4 vCPU / 12 Go) a un quota de 0 sur les organisations récentes (constaté le 2026-09-26) ;
  # BASIC2-A4C-16G : 4 vCPU / 16 Go, prix voisin (~0,069 EUR/h), quota disponible par défaut.
  default     = "BASIC2-A4C-16G"
  description = "GitLab Omnibus : 4 vCPU / 8 Go minimum recommandés"
}

variable "runner_version" {
  type    = string
  default = "19.4.0-1"
}

variable "runner_instance_type" {
  type    = string
  default = "DEV1-L"
}

variable "runner_concurrency" {
  type    = number
  default = 4
}

variable "k8s_version" {
  type    = string
  default = "1.37"
}

variable "k8s_node_type" {
  type    = string
  default = "DEV1-M"
}

variable "k8s_node_count" {
  type    = number
  default = 2
}
