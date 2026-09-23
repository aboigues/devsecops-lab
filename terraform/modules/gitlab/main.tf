resource "scaleway_instance_ip" "gitlab" {
  tags = var.tags
}

locals {
  # sslip.io : DNS public qui résout gitlab.<ip>.sslip.io vers <ip> -> certificat Let's Encrypt
  # sans nom de domaine à gérer (lab éphémère)
  ip_dashed     = replace(scaleway_instance_ip.gitlab.address, ".", "-")
  host          = "gitlab.${local.ip_dashed}.sslip.io"
  registry_host = "registry.${local.ip_dashed}.sslip.io"
}

resource "scaleway_instance_security_group" "gitlab" {
  name                    = "${var.name}-gitlab"
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"
  stateful                = true
  tags                    = var.tags

  # SSH réservé aux postes d'administration
  dynamic "inbound_rule" {
    for_each = var.admin_cidrs
    content {
      action   = "accept"
      port     = 22
      ip_range = inbound_rule.value
    }
  }

  # HTTP ouvert : challenge ACME Let's Encrypt, puis redirection vers HTTPS
  inbound_rule {
    action = "accept"
    port   = 80
  }

  # HTTPS ouvert : apprenants (interface, git, registry) et noeuds Kapsule
  inbound_rule {
    action = "accept"
    port   = 443
  }
}

resource "scaleway_instance_server" "gitlab" {
  name              = "${var.name}-gitlab"
  type              = var.instance_type
  image             = "ubuntu_noble"
  ip_id             = scaleway_instance_ip.gitlab.id
  security_group_id = scaleway_instance_security_group.gitlab.id
  tags              = var.tags

  root_volume {
    size_in_gb            = var.root_volume_size_gb
    delete_on_termination = true
  }

  private_network {
    pn_id = var.private_network_id
  }

  user_data = {
    cloud-init = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      gitlab_version    = var.gitlab_version
      host              = local.host
      registry_host     = local.registry_host
      letsencrypt_email = var.letsencrypt_email
      root_password     = var.root_password
      terraform_token   = var.terraform_token
      runner_token      = var.runner_token
    })
  }
}
