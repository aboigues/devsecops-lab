# Étape 0 — exécutée une seule fois, state local : crée le bucket qui héberge
# le state distant des étapes suivantes (poule et oeuf classique de l'IaC).
terraform {
  required_version = ">= 1.14"
  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.83"
    }
  }
}

provider "scaleway" {
  region = var.region
}

variable "region" {
  type    = string
  default = "fr-par"
}

variable "bucket_name" {
  type        = string
  description = "Nom globalement unique du bucket de state"
}

resource "scaleway_object_bucket" "tfstate" {
  name = var.bucket_name

  # Versioning : permet de restaurer un state corrompu ou écrasé
  versioning {
    enabled = true
  }
}

resource "scaleway_object_bucket_acl" "tfstate" {
  bucket = scaleway_object_bucket.tfstate.id
  acl    = "private"
}

output "bucket" {
  value = scaleway_object_bucket.tfstate.name
}
