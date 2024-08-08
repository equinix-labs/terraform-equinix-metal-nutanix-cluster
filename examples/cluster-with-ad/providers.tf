terraform {
  required_version = ">= 1.0"

  provider_meta "equinix" {
    module_name = "equinix-metal-nutanix-cluster"
  }

  required_providers {
    equinix = {
      source  = "equinix/equinix"
      version = ">= 1.30"
    }

    null = {
      source  = "hashicorp/null"
      version = ">= 3"
    }
  }
}

# Configure the Equinix Metal credentials.
provider "equinix" {
  auth_token = var.metal_auth_token
}
