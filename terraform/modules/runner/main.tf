resource "scaleway_instance_ip" "runner" {
  tags = var.tags
}

resource "scaleway_instance_security_group" "runner" {
  name                    = "${var.name}-runner"
  inbound_default_policy  = "drop"
  outbound_default_policy = "accept"
  stateful                = true
  tags                    = var.tags

  # Aucun port applicatif exposé : le runner initie toutes les connexions (polling GitLab)
  dynamic "inbound_rule" {
    for_each = var.admin_cidrs
    content {
      action   = "accept"
      port     = 22
      ip_range = inbound_rule.value
    }
  }
}

resource "scaleway_instance_server" "runner" {
  name              = "${var.name}-runner"
  type              = var.instance_type
  image             = "ubuntu_noble"
  ip_id             = scaleway_instance_ip.runner.id
  security_group_id = scaleway_instance_security_group.runner.id
  tags              = var.tags

  root_volume {
    size_in_gb            = 60
    delete_on_termination = true
  }

  private_network {
    pn_id = var.private_network_id
  }

  user_data = {
    cloud-init = templatefile("${path.module}/cloud-init.yaml.tftpl", {
      runner_version = var.runner_version
      concurrency    = var.concurrency
      gitlab_url     = var.gitlab_url
      runner_token   = var.runner_token
    })
  }
}
