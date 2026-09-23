resource "scaleway_k8s_cluster" "lab" {
  name                        = "${var.name}-k8s"
  version                     = var.k8s_version
  cni                         = "cilium"
  private_network_id          = var.private_network_id
  delete_additional_resources = true
  tags                        = var.tags

  auto_upgrade {
    enable                        = true
    maintenance_window_start_hour = 3
    maintenance_window_day        = "sunday"
  }
}

resource "scaleway_k8s_pool" "default" {
  cluster_id  = scaleway_k8s_cluster.lab.id
  name        = "default"
  node_type   = var.node_type
  size        = var.node_count
  autohealing = true
  tags        = var.tags
}
