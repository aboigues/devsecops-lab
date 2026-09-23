terraform {
  required_version = ">= 1.14"

  required_providers {
    scaleway = {
      source  = "scaleway/scaleway"
      version = ">= 2.83"
    }
  }
}
