locals {
  project_id = var.create_project ? element(equinix_metal_project.nutanix[*].id, 0) : element(data.equinix_metal_project.nutanix[*].id, 0)
  num_nodes  = 1
  subnet     = "192.168.100.0/25"
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
  metro       = var.metal_metro
}

resource "equinix_metal_device" "bastion" {
  project_id = local.project_id
  hostname   = "bastion"
  user_data = templatefile("${path.module}/templates/bastion-userdata.tftpl", {
    metal_vlan_id : equinix_metal_vlan.nutanix.vxlan,
    address : cidrhost(local.subnet, 2),
    netmask : cidrnetmask(local.subnet)
  })
  operating_system = "ubuntu_22_04"
  plan             = "c3.small.x86"
  metro            = var.metal_metro
  #project_ssh_key_ids = [equinix_metal_project_ssh_key.ssh_key.id]
}

resource "equinix_metal_port" "bastion_bond0" {
  port_id  = [for p in equinix_metal_device.bastion.ports : p.id if p.name == "bond0"][0]
  layer2   = false
  bonded   = true
  vlan_ids = [equinix_metal_vlan.nutanix.id]
}

resource "equinix_metal_vrf" "nutanix" {
  description = "VRF with ASN 65000 and a pool of address space that includes 192.168.100.0/25"
  name        = "nutanix-vrf"
  metro       = var.metal_metro
  local_asn   = "65000"
  ip_ranges   = [local.subnet]
  project_id  = local.project_id
}

resource "equinix_metal_reserved_ip_block" "nutanix" {
  description = "Reserved IP block (${local.subnet}) taken from on of the ranges in the VRF's pool of address space."
  project_id  = local.project_id
  metro       = var.metal_metro
  type        = "vrf"
  vrf_id      = equinix_metal_vrf.nutanix.id
  cidr        = split("/", local.subnet)[1]
  network     = cidrhost(local.subnet, 0)
}

resource "equinix_metal_gateway" "gateway" {
  project_id        = local.project_id
  vlan_id           = equinix_metal_vlan.nutanix.id
  ip_reservation_id = equinix_metal_reserved_ip_block.nutanix.id
}

resource "equinix_metal_device" "nutanix" {
  count            = local.num_nodes
  project_id       = local.project_id
  hostname         = "nutanix-devrel-test-${count.index}"
  operating_system = "nutanix_lts_6_5"
  plan             = "m3.large.x86"
  metro            = var.metal_metro
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
