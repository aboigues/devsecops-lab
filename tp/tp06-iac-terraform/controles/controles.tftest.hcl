# Contrôles de verify.sh : copiés à côté de VOS tests dans une copie de travail, puis exécutés
# par « terraform test ». Aucun appel à Scaleway : le fournisseur est simulé (mock_provider).

mock_provider "scaleway" {}

variables {
  admin_cidrs = ["203.0.113.10/32"]
}

run "controle_entree_refusee_par_defaut" {
  command = plan

  assert {
    condition     = scaleway_instance_security_group.bastion.inbound_default_policy == "drop"
    error_message = "Le groupe de sécurité doit refuser par défaut tout trafic entrant (drop)."
  }
}

run "controle_ssh_limite_aux_admins" {
  command = plan

  assert {
    condition = alltrue([
      for r in scaleway_instance_security_group.bastion.inbound_rule :
      r.port != 22 || contains(var.admin_cidrs, r.ip_range)
    ])
    error_message = "Le port 22 ne doit être ouvert qu'aux plages admin_cidrs."
  }
}

run "controle_bucket_prive_et_versionne" {
  command = plan

  assert {
    condition     = scaleway_object_bucket_acl.exports.acl == "private"
    error_message = "Le bucket d'exports doit être privé."
  }

  assert {
    condition     = scaleway_object_bucket.exports.versioning[0].enabled
    error_message = "Le bucket d'exports doit être versionné."
  }
}

run "controle_ssh_monde_entier_refuse_ipv4" {
  command = plan

  variables {
    admin_cidrs = ["203.0.113.10/32", "0.0.0.0/0"]
  }

  expect_failures = [var.admin_cidrs]
}

run "controle_ssh_monde_entier_refuse_ipv6" {
  command = plan

  variables {
    admin_cidrs = ["::/0"]
  }

  expect_failures = [var.admin_cidrs]
}

run "controle_cidr_invalide_refuse" {
  command = plan

  variables {
    admin_cidrs = ["mon-ip"]
  }

  expect_failures = [var.admin_cidrs]
}
