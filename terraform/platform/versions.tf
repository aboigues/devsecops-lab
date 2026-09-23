terraform {
  required_version = ">= 1.14"

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = "~> 2.83"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }

  # Configuration partielle : bucket et clés passés via backend.hcl (non versionné)
  # terraform init -backend-config=../backend.hcl
  backend "s3" {
    key                         = "platform.tfstate"
    region                      = "fr-par"
    endpoints                   = { s3 = "https://s3.fr-par.scw.cloud" }
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
    use_lockfile                = true
  }
}

provider "scaleway" {
  region = var.region
  zone   = var.zone
}
