locals {
  project_id = module.nutanix_cluster.nutanix_metal_project_id
  vlan_id    = module.nutanix_cluster.nutanix_metal_vlan_id
  vxlan      = data.equinix_metal_vlan.nutanix.vxlan
}
