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

module "nutanix" {
  source = "../../"

  metal_auth_token        = var.metal_auth_token
  metal_vlan_description  = var.metal_vlan_description
  metal_project_name      = var.metal_project_name
  metal_project_id        = var.metal_project_id
  metal_organization_id   = var.metal_organization_id
  metal_metro             = var.metal_metro
  create_project          = var.create_project
  metal_bastion_plan      = var.metal_bastion_plan
  create_vlan             = var.create_vlan
  metal_vlan_id           = var.metal_vlan_id
  nutanix_node_count      = var.nutanix_node_count
  skip_cluster_creation   = var.skip_cluster_creation
  nutanix_reservation_ids = var.nutanix_reservation_ids
  metal_nutanix_os        = var.metal_nutanix_os
  metal_nutanix_plan      = var.metal_nutanix_plan
}
