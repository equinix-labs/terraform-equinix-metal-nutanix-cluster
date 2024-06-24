locals {
  project_id = module.nutanix-cluster.nutanix_metal_project_id
  vlan_id    = module.nutanix-cluster.nutanix_metal_vlan_id
  vxlan = data.equinix_metal_vlan.nutanix.vxlan

  ad_domain_name = "equinixad.com"
  ad_admin_user = "Admin"
}