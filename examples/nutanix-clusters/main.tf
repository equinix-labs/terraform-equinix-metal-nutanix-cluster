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

    random = {
      source  = "hashicorp/random"
      version = ">= 3"
    }

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

module "nutanix_cluster1" {
  source  = "equinix-labs/metal-nutanix-cluster/equinix"
  version = "0.1.2"
  metal_auth_token  = var.metal_auth_token
  metal_metro       = var.metal_metro
  create_project    = false
  metal_project_id  = var.metal_project_id
  #metal_subnet = "192.168.100.0/22"
  nutanix_node_count = var.nutanix_node_count
}

module "nutanix_cluster2" {
  source  = "equinix-labs/metal-nutanix-cluster/equinix"
  version = "0.1.2"
  metal_auth_token  = var.metal_auth_token
  metal_metro       = var.metal_metro
  create_project    = false
  metal_project_id  = var.metal_project_id
  #metal_subnet = "192.168.104.0/22"
  nutanix_node_count = var.nutanix_node_count
}
