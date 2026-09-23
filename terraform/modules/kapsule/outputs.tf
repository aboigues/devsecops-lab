output "cluster_id" {
  value = scaleway_k8s_cluster.lab.id
}

output "kubeconfig" {
  sensitive = true
  value = {
    host                   = scaleway_k8s_cluster.lab.kubeconfig[0].host
    token                  = scaleway_k8s_cluster.lab.kubeconfig[0].token
    cluster_ca_certificate = scaleway_k8s_cluster.lab.kubeconfig[0].cluster_ca_certificate
    raw                    = scaleway_k8s_cluster.lab.kubeconfig[0].config_file
  }
}
