/*
resource equinix_metal_project_ssh_key ssh_key {
  name       = nutanix-ssh-key
  project_id = local.project_id
  public_key = tls_private_key.ssh_key.public_key_openssh
} */

/* resource equinix_metal_port nutanix_bond0 {
  for_each = { for idx, val in equinix_metal_device.nutanix : idx => val }
  port_id  = [for p in each.value.ports : p.id if p.name == bond0][0]
  layer2   = true
  bonded   = true
  vlan_ids = [equinix_metal_vlan.test.id]
} */

/* resource tls_private_key ssh_key {
  algorithm = RSA
  rsa_bits  = 4096
}
 */


locals {
  project_id = var.create_project ? element(equinix_metal_project.nutanix[*].id, 0) : element(data.equinix_metal_project.nutanix[*].id, 0)
  num_nodes  = 1
}

resource "equinix_metal_project" "nutanix" {
  count           = var.create_project ? 1 : 0
  name            = var.metal_project_name
  organization_id = var.metal_organization_id
}

data "equinix_metal_project" "nutanix" {
  count = var.create_project ? 0 : 1
  name  = var.metal_project_name
}

module "ssh" {
  source = "./modules/ssh/"
}

resource "equinix_metal_vlan" "nutanix" {
  project_id  = local.project_id
  description = var.metal_vlan_description
  metro       = "da"
}

resource "equinix_metal_device" "bastion" {
  project_id = local.project_id
  hostname   = "bastion"
  user_data = templatefile("${path.module}/templates/bastion-userdata.tftpl", {
    metal_vlan_id : equinix_metal_vlan.nutanix.vxlan,

  })
  operating_system = "ubuntu_22_04"
  plan             = "c3.small.x86"
  metro            = "da"
  #project_ssh_key_ids = [equinix_metal_project_ssh_key.ssh_key.id]
}

resource "equinix_metal_port" "bastion_bond0" {
  port_id  = [for p in equinix_metal_device.bastion.ports : p.id if p.name == "bond0"][0]
  layer2   = false
  bonded   = true
  vlan_ids = [equinix_metal_vlan.nutanix.id]
}

resource "equinix_metal_gateway" "gateway" {
  project_id               = local.project_id
  vlan_id                  = equinix_metal_vlan.nutanix.id
  private_ipv4_subnet_size = 128
}

resource "equinix_metal_device" "nutanix" {
  count            = local.num_nodes
  project_id       = local.project_id
  hostname         = "nutanix-devrel-test-${count.index}"
  operating_system = "nutanix_lts_6_5"
  plan             = "m3.large.x86"
  metro            = "da"
  ip_address {
    type = "private_ipv4"
  }
}

resource "equinix_metal_port" "nutanix" {
  count    = local.num_nodes
  port_id  = [for p in equinix_metal_device.nutanix[count.index].ports : p.id if p.name == "bond0"][0]
  bonded   = true
  vlan_ids = [equinix_metal_vlan.nutanix.id]
}
