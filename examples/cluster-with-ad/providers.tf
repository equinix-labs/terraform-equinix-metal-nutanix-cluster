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

    # tflint-ignore: terraform_unused_required_providers
    null = {
      source  = "hashicorp/null"
      version = ">= 3"
    }

    random = {
      source  = "hashicorp/random"
      version = ">= 3"
    }

    # tflint-ignore: terraform_unused_required_providers
    local = {
      source  = "hashicorp/local"
      version = ">= 2.5"
    }
  }
}

# Configure the Equinix Metal credentials.
provider "equinix" {
  auth_token = var.metal_auth_token
}
