terraform {
  required_version = ">= 1.14"

  required_providers {
    gitlab = {
      source  = "gitlabhq/gitlab"
      version = "~> 19.4"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3.2"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.14"
    }
  }

  backend "s3" {
    key                         = "labs.tfstate"
    region                      = "fr-par"
    endpoints                   = { s3 = "https://s3.fr-par.scw.cloud" }
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_lockfile                = true
  }
}

# Étape 2 : consomme les sorties de l'étape « platform » via son state distant.
# Séparer les étapes évite de configurer un provider (gitlab, kubernetes)
# avec des valeurs inconnues au moment du plan.
data "terraform_remote_state" "platform" {
  backend = "s3"
  config = {
    bucket                      = var.state_bucket
    key                         = "platform.tfstate"
    region                      = "fr-par"
    endpoints                   = { s3 = "https://s3.fr-par.scw.cloud" }
    access_key                  = var.state_access_key
    secret_key                  = var.state_secret_key
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

locals {
  platform = data.terraform_remote_state.platform.outputs
  kube     = local.platform.kubeconfig
}

provider "gitlab" {
  base_url = "${local.platform.gitlab_url}/api/v4/"
  token    = local.platform.gitlab_terraform_token
}

provider "kubernetes" {
  host                   = local.kube.host
  token                  = local.kube.token
  cluster_ca_certificate = base64decode(local.kube.cluster_ca_certificate)
}

provider "helm" {
  kubernetes = {
    host                   = local.kube.host
    token                  = local.kube.token
    cluster_ca_certificate = base64decode(local.kube.cluster_ca_certificate)
  }
}
