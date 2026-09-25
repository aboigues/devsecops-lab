resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name

  # Valeurs partagées avec le scan hebdomadaire des images (commentées dans le fichier)
  values = [file("${path.module}/argocd-values.yaml")]
}

resource "kubernetes_namespace_v1" "learner" {
  for_each = var.learners
  metadata {
    name = "lab-${each.key}"
    labels = {
      # Pod Security Admission : refuse tout pod root, privilégié ou avec capacités
      "pod-security.kubernetes.io/enforce" = "restricted"
    }
  }
}

# Isolation réseau entre apprenants : seul le trafic interne au namespace est admis
resource "kubernetes_network_policy_v1" "isolate" {
  for_each = var.learners
  metadata {
    name      = "same-namespace-only"
    namespace = kubernetes_namespace_v1.learner[each.key].metadata[0].name
  }
  spec {
    pod_selector {}
    policy_types = ["Ingress"]
    ingress {
      from {
        pod_selector {}
      }
    }
  }
}

resource "kubernetes_secret_v1" "registry" {
  for_each = var.learners
  metadata {
    name      = "gitlab-registry"
    namespace = kubernetes_namespace_v1.learner[each.key].metadata[0].name
  }
  type = "kubernetes.io/dockerconfigjson"
  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        (local.platform.registry_host) = {
          username = gitlab_project_deploy_token.argocd[each.key].username
          password = gitlab_project_deploy_token.argocd[each.key].token
        }
      }
    })
  }
}

resource "kubernetes_secret_v1" "argocd_repo" {
  for_each = var.learners
  metadata {
    name      = "repo-${each.key}"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }
  data = {
    type     = "git"
    url      = gitlab_project.learner[each.key].http_url_to_repo
    username = gitlab_project_deploy_token.argocd[each.key].username
    password = gitlab_project_deploy_token.argocd[each.key].token
  }
}

# Applications déclarées via le chart argocd-apps : évite la dépendance aux CRD
# au moment du plan (limite connue de kubernetes_manifest)
resource "helm_release" "applications" {
  name       = "lab-applications"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = var.argocd_apps_chart_version
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name

  values = [yamlencode({
    applications = {
      for l in var.learners : "bank-api-${l}" => {
        namespace = "argocd"
        project   = "default"
        source = {
          repoURL        = gitlab_project.learner[l].http_url_to_repo
          targetRevision = "main"
          path           = "gitops/overlays/lab"
        }
        destination = {
          server    = "https://kubernetes.default.svc"
          namespace = "lab-${l}"
        }
        syncPolicy = {
          automated = { prune = true, selfHeal = true }
        }
      }
    }
  })]

  depends_on = [helm_release.argocd, kubernetes_secret_v1.argocd_repo]
}
