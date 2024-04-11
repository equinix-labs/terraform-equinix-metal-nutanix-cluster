terraform {
  required_version = ">= 1.0"
  required_providers {
    equinix = {
      source  = "equinix/equinix"
      version = ">= 1.30"
    }
  }
}

# Configure the Equinix Metal Provider.
provider "equinix" {
  auth_token = var.metal_auth_token
}
