variable "nom" {
  type        = string
  description = "Préfixe des ressources (ex. neobanque-lab)"
  default     = "neobanque-lab"
}

variable "admin_cidrs" {
  type        = list(string)
  description = "Plages autorisées en SSH (ex. IP publique de l'administrateur en /32)"
  # TODO 1 : supprimer cette valeur par défaut « pour que ça marche » : SSH ouvert au monde entier.
  default = ["0.0.0.0/0"]

  # TODO 2 : ajouter un bloc validation qui refuse toute valeur qui n'est pas un CIDR valide,
  #          ainsi que 0.0.0.0/0 et ::/0 (fonctions utiles : alltrue, can, cidrhost, contains).
}
