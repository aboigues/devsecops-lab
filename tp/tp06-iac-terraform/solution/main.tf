# Bastion d'administration et bucket d'exports de Néobanque Exemple.

resource "scaleway_instance_security_group" "bastion" {
  name                    = "${var.nom}-bastion"
  inbound_default_policy  = "drop"
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

  # Versioning : un export écrasé ou supprimé par erreur (ou par un rançongiciel) reste récupérable
  versioning {
    enabled = true
  }
}

resource "scaleway_object_bucket_acl" "exports" {
  bucket = scaleway_object_bucket.exports.id
  acl    = "private"
}
