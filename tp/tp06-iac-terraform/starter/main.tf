# Bastion d'administration et bucket d'exports de Néobanque Exemple.

resource "scaleway_instance_security_group" "bastion" {
  name = "${var.nom}-bastion"
  # TODO 3 : tout ce qui n'est pas explicitement autorisé doit être refusé en entrée.
  inbound_default_policy  = "accept"
  outbound_default_policy = "accept"
  stateful                = true

  # SSH réservé aux postes d'administration
  dynamic "inbound_rule" {
    for_each = var.admin_cidrs
    content {
      action   = "accept"
      port     = 22
      ip_range = inbound_rule.value
    }
  }
}

resource "scaleway_object_bucket" "exports" {
  name = "${var.nom}-exports"

  # TODO 4 : activer le versioning (un export écrasé ou supprimé doit rester récupérable).
  versioning {
    enabled = false
  }
}

resource "scaleway_object_bucket_acl" "exports" {
  bucket = scaleway_object_bucket.exports.id
  # TODO 5 : les exports contiennent des données clients : le bucket ne doit PAS être public.
  acl = "public-read"
}
