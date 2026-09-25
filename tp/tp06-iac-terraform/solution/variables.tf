variable "nom" {
  type        = string
  description = "Préfixe des ressources (ex. neobanque-lab)"
  default     = "neobanque-lab"
}

variable "admin_cidrs" {
  type        = list(string)
  description = "Plages autorisées en SSH (ex. IP publique de l'administrateur en /32)"
  # Pas de valeur par défaut : l'ouverture SSH est un choix explicite, jamais un oubli.

  validation {
    condition     = alltrue([for c in var.admin_cidrs : can(cidrhost(c, 0)) && !contains(["0.0.0.0/0", "::/0"], c)])
    error_message = "admin_cidrs doit contenir des CIDR valides, jamais 0.0.0.0/0 ni ::/0."
  }
}
