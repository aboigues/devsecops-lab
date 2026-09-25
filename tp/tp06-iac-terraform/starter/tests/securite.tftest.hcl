# Tests de sécurité du module : exécutés hors ligne (« terraform test »), fournisseur simulé.

mock_provider "scaleway" {}

variables {
  admin_cidrs = ["198.51.100.7/32"]
}

run "le_groupe_de_securite_refuse_par_defaut" {
  command = plan

  assert {
    condition     = scaleway_instance_security_group.bastion.inbound_default_policy == "drop"
    error_message = "Politique d'entrée par défaut attendue : drop."
  }
}

# TODO 6 : un bloc run qui vérifie que le bucket d'exports est privé ET versionné.

# TODO 7 : un bloc run qui prouve que admin_cidrs = ["0.0.0.0/0"] est REFUSÉ par la validation
#          (indice : expect_failures).
