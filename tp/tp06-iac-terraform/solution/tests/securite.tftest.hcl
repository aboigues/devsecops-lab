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

run "le_bucket_d_exports_est_prive" {
  command = plan

  assert {
    condition     = scaleway_object_bucket_acl.exports.acl == "private"
    error_message = "ACL attendue : private."
  }

  assert {
    condition     = scaleway_object_bucket.exports.versioning[0].enabled
    error_message = "Le versioning doit être activé."
  }
}

run "ssh_ouvert_au_monde_refuse" {
  command = plan

  variables {
    admin_cidrs = ["0.0.0.0/0"]
  }

  expect_failures = [var.admin_cidrs]
}
