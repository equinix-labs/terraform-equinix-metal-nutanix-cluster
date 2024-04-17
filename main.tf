locals {
  project_id = var.create_project ? element(equinix_metal_project.nutanix[*].id, 0) : element(data.equinix_metal_project.nutanix[*].id, 0)
  num_nodes  = 1
  # Pick an arbitrary private subnet, we recommend a /25 like "192.168.100.0/22"
  subnet = "192.168.100.0/22"
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
  source     = "./modules/ssh/"
  project_id = local.project_id
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
    netmask : cidrnetmask(local.subnet),
    host_dhcp_start : cidrhost(local.subnet, 3),
    host_dhcp_end : cidrhost(local.subnet, 15),
    vm_dhcp_start : cidrhost(local.subnet, 16),
    vm_dhcp_end : cidrhost(local.subnet, -2),
    lease-time : "infinite",
    nutanix_mac : "50:6b:8d:*:*:*",
    set : "nutanix"
  })
  operating_system    = "ubuntu_22_04"
  plan                = "c3.small.x86"
  metro               = var.metal_metro
  project_ssh_key_ids = [module.ssh.equinix_metal_ssh_key_id]
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

resource "null_resource" "wait_for_firstboot" {
  count = local.num_nodes

  depends_on = [
    equinix_metal_port.bastion_bond0,
    module.ssh.ssh_private_key,
    equinix_metal_vrf.nutanix,
    equinix_metal_vlan.nutanix,
    equinix_metal_gateway.gateway,
    equinix_metal_reserved_ip_block.nutanix,
    equinix_metal_device.nutanix
  ]

  connection {
    bastion_host        = equinix_metal_device.bastion.access_public_ipv4
    bastion_user        = "root"
    bastion_private_key = chomp(module.ssh.ssh_private_key_contents)
    type                = "ssh"
    user                = "root"
    host                = equinix_metal_device.nutanix[count.index].access_private_ipv4
    password            = "nutanix/4u"
    script_path         = "/root/firstboot-check-%RAND%.sh"
  }
  provisioner "remote-exec" {
    script = "scripts/firstboot-check.sh"
  }
}

resource "null_resource" "change_cvm_passwd" {
  count = local.num_nodes

  depends_on = [
    null_resource.wait_for_firstboot
  ]

  connection {
    bastion_host        = equinix_metal_device.bastion.access_public_ipv4
    bastion_user        = "root"
    bastion_private_key = chomp(module.ssh.ssh_private_key_contents)
    type                = "ssh"
    user                = "root"
    host                = equinix_metal_device.nutanix[count.index].access_private_ipv4
    password            = "nutanix/4u"
    script_path         = "/root/change-cvm-passwd-%RAND%.sh"
  }
  provisioner "remote-exec" {
    script = "scripts/change-cvm-passwd.sh"
  }
}

resource "equinix_metal_port" "nutanix" {
  depends_on = [null_resource.change_cvm_passwd]
  count      = local.num_nodes
  port_id    = [for p in equinix_metal_device.nutanix[count.index].ports : p.id if p.name == "bond0"][0]
  layer2     = true
  bonded     = true
  vlan_ids   = [equinix_metal_vlan.nutanix.id]

}



resource "null_resource" "reboot_nutanix" {
  count = local.num_nodes

  depends_on = [
    equinix_metal_port.nutanix
  ]

  connection {
    host        = equinix_metal_device.bastion.access_public_ipv4
    private_key = chomp(module.ssh.ssh_private_key_contents)
    type        = "ssh"
    user        = "root"
  }
  provisioner "file" {
    destination = "/root/reboot-nutanix.sh"
    content = templatefile("${path.module}/templates/reboot-nutanix.sh.tmpl", {
      device_uuid = equinix_metal_device.nutanix[count.index].id,
      auth_token  = var.metal_auth_token
    })
  }
  provisioner "remote-exec" {
    inline = ["/bin/sh /root/reboot-nutanix.sh"]
  }
}

resource "null_resource" "wait_for_dhcp" {
  count = local.num_nodes

  depends_on = [
    null_resource.reboot_nutanix
  ]

  connection {
    host        = equinix_metal_device.bastion.access_public_ipv4
    private_key = chomp(module.ssh.ssh_private_key_contents)
    type        = "ssh"
    user        = "root"
    script_path = "/root/dhcp-check-%RAND%.sh"
  }
  provisioner "remote-exec" {
    script = "scripts/dhcp-check.sh"
  }
}



