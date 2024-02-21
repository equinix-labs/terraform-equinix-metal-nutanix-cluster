data "equinix_metal_project" "nutanix" {
  name = "devrel-marques-testing"
}

resource "equinix_metal_vlan" "test" {
  project_id  = data.equinix_metal_project.nutanix.id
  description = var.metal_vlan_description
  metro       = "da"
}

resource "equinix_metal_device" "bastion" {
  project_id = data.equinix_metal_project.nutanix.id
  hostname   = "bastion"
  user_data = templatefile("bastion-userdata.tmpl", {
    metal_auth_token       = var.metal_auth_token
    metal_vlan_description = var.metal_vlan_description
  })
  operating_system = "rocky_9"
  plan             = "c3.small.x86"
  metro            = "da"
}

resource "equinix_metal_port" "bastion_bond0" {
  port_id  = [for p in equinix_metal_device.bastion.ports : p.id if p.name == "bond0"][0]
  layer2   = false
  bonded   = true
  vlan_ids = [equinix_metal_vlan.test.id]
}

resource "equinix_metal_device" "nutanix" {
  count            = 1
  project_id       = data.equinix_metal_project.nutanix.id
  hostname         = "nutanix-devrel-test-{count.index}"
  user_data        = templatefile("nutanix-userdata.tmpl", {})
  operating_system = "nutanix_lts_6_5"
  plan             = "m3.large.x86"
  metro            = "da"
}

resource "equinix_metal_port" "nutanix_bond0" {
  for_each = equinix_metal_device.nutanix
  port_id  = [for p in each.value.ports : p.id if p.name == "bond0"][0]
  layer2   = true
  bonded   = true
  vlan_ids = [equinix_metal_vlan.test.id]
}

