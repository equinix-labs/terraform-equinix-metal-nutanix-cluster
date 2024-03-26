locals {
  project_id = var.create_project ? equinix_metal_project.nutanix[*].id[0] : data.equinix_metal_project.nutanix.id
}

resource "equinix_metal_project" "nutanix" {
  count = var.create_project ? 1 : 0
  name  = var.metal_project_name
}

data "equinix_metal_project" "nutanix" {
  name = var.metal_project_name
}

resource "equinix_metal_vlan" "test" {
  project_id  = local.project_id
  description = var.metal_vlan_description
  metro       = "da"
}

resource "equinix_metal_device" "bastion" {
  project_id = local.project_id
  hostname   = "bastion"
  user_data = templatefile("${path.module}/templates/bastion-userdata.tftpl", {
    "metal_auth_token" : var.metal_auth_token,
    "metal_vlan_description" : var.metal_vlan_description,
    "metal_vlan_id" : equinix_metal_vlan.test.vxlan
  })
  operating_system    = "rocky_9"
  plan                = "c3.small.x86"
  metro               = "da"
  project_ssh_key_ids = [equinix_metal_project_ssh_key.ssh_key.id]
}

resource "equinix_metal_port" "bastion_bond0" {
  port_id  = [for p in equinix_metal_device.bastion.ports : p.id if p.name == "bond0"][0]
  layer2   = false
  bonded   = true
  vlan_ids = [equinix_metal_vlan.test.id]
}

resource "equinix_metal_device" "nutanix" {
  count            = 1
  project_id       = local.project_id
  hostname         = "nutanix-devrel-test-${count.index}"
  user_data        = templatefile("${path.module}/templates/nutanix-userdata.tftpl", {})
  operating_system = "nutanix_lts_6_5"
  plan             = "m3.large.x86"
  metro            = "da"
}

resource "equinix_metal_project_ssh_key" "ssh_key" {
  name       = "nutanix-ssh-key"
  project_id = local.project_id
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "equinix_metal_port" "nutanix_bond0" {
  for_each = { for idx, val in equinix_metal_device.nutanix : idx => val }
  port_id  = [for p in each.value.ports : p.id if p.name == "bond0"][0]
  layer2   = true
  bonded   = true
  vlan_ids = [equinix_metal_vlan.test.id]
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}
