terraform {
  required_providers {
    equinix = {
      source = "equinix/equinix"
    }
  }
}

# Configure the Equinix Metal Provider.
provider "equinix" {
  auth_token = var.metal_auth_token
}
