locals {
  project_id = var.create_project ? element(equinix_metal_project.nutanix[*].id, 0) : (var.metal_project_id != "") ? var.metal_project_id : element(data.equinix_metal_project.nutanix[*].id, 0)
  vlan_id    = var.create_vlan ? element(equinix_metal_vlan.nutanix[*].id, 0) : element(data.equinix_metal_vlan.nutanix[*].id, 0)
  vxlan      = var.create_vlan ? element(equinix_metal_vlan.nutanix[*].vxlan, 0) : element(data.equinix_metal_vlan.nutanix[*].vxlan, 0)

  # Pick an arbitrary private subnet, we recommend a /22 like "192.168.100.0/22"
  subnet = "192.168.100.0/22"
}

resource "equinix_metal_project" "nutanix" {
  count           = var.create_project ? 1 : 0
  name            = var.metal_project_name
  organization_id = var.metal_organization_id
}

data "equinix_metal_project" "nutanix" {
  count = (var.create_project || var.metal_project_id != "") ? 0 : 1
  name  = var.metal_project_name
}

module "ssh" {
  source     = "./modules/ssh/"
  project_id = local.project_id
}

resource "equinix_metal_vlan" "nutanix" {
  count = var.create_vlan ? 1 : 0

  project_id  = local.project_id
  description = var.metal_vlan_description
  metro       = var.metal_metro
}

data "equinix_metal_vlan" "nutanix" {
  count = var.create_vlan ? 0 : 1

  project_id = local.project_id
  vxlan      = var.metal_vlan_id
}



resource "equinix_metal_device" "bastion" {
  project_id = local.project_id
  hostname   = "bastion"

  user_data = templatefile("${path.module}/templates/bastion-userdata.tmpl", {
    metal_vlan_id   = local.vxlan,
    address         = cidrhost(local.subnet, 2),
    netmask         = cidrnetmask(local.subnet),
    host_dhcp_start = cidrhost(local.subnet, 3),
    host_dhcp_end   = cidrhost(local.subnet, 15),
    vm_dhcp_start   = cidrhost(local.subnet, 16),
    vm_dhcp_end     = cidrhost(local.subnet, -2),
    lease_time      = "infinite",
    nutanix_mac     = "50:6b:8d:*:*:*",
    set             = "nutanix"
  })

  operating_system    = "ubuntu_22_04"
  plan                = var.metal_bastion_plan
  metro               = var.metal_metro
  project_ssh_key_ids = [module.ssh.equinix_metal_ssh_key_id]
}

resource "equinix_metal_port" "bastion_bond0" {
  port_id  = [for p in equinix_metal_device.bastion.ports : p.id if p.name == "bond0"][0]
  layer2   = false
  bonded   = true
  vlan_ids = [local.vlan_id]
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
  vlan_id           = local.vlan_id
  ip_reservation_id = equinix_metal_reserved_ip_block.nutanix.id
}

resource "equinix_metal_device" "nutanix" {
  count                   = var.nutanix_node_count
  project_id              = local.project_id
  hostname                = "nutanix-devrel-test-${count.index}"
  operating_system        = "nutanix_lts_6_5"
  plan                    = "m3.large.x86"
  metro                   = var.metal_metro
  hardware_reservation_id = "next-available"

  ip_address {
    type = "private_ipv4"
  }
}

resource "null_resource" "wait_for_firstboot" {
  count = var.nutanix_node_count

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



resource "equinix_metal_port" "nutanix" {
  depends_on = [null_resource.wait_for_firstboot]
  count      = var.nutanix_node_count
  port_id    = [for p in equinix_metal_device.nutanix[count.index].ports : p.id if p.name == "bond0"][0]
  layer2     = true
  bonded     = true
  vlan_ids   = [local.vlan_id]

}

resource "null_resource" "reboot_nutanix" {
  count = var.nutanix_node_count

  depends_on = [
    equinix_metal_port.nutanix
  ]

  connection {
    host        = equinix_metal_device.bastion.access_public_ipv4
    private_key = chomp(module.ssh.ssh_private_key_contents)
    type        = "ssh"
    user        = "root"
    script_path = "/root/reboot-nutanix-%RAND%.sh"
  }

  provisioner "remote-exec" {
    inline = ["curl -fsSL https://api.equinix.com/metal/v1/devices/${equinix_metal_device.nutanix[count.index].id}/actions -H \"Content-Type: application/json\" -H \"X-Auth-Token: ${var.metal_auth_token}\" -d  '{\"type\": \"reboot\"}'"]
  }
}

resource "null_resource" "wait_for_dhcp" {
  depends_on = [
    null_resource.reboot_nutanix
  ]

  connection {
    host        = equinix_metal_device.bastion.access_public_ipv4
    private_key = chomp(module.ssh.ssh_private_key_contents)
    type        = "ssh"
    user        = "root"
  }

  provisioner "file" {
    destination = "/root/dhcp-check.sh"
    content = templatefile("${path.module}/templates/dhcp-check.sh.tmpl", {
      num_nodes = var.nutanix_node_count
    })
  }

  provisioner "remote-exec" {
    inline = ["/bin/sh /root/dhcp-check.sh"]
  }
}

resource "null_resource" "finalize_cluster" {
  depends_on = [
    null_resource.wait_for_dhcp
  ]

  connection {
    host        = equinix_metal_device.bastion.access_public_ipv4
    private_key = chomp(module.ssh.ssh_private_key_contents)
    type        = "ssh"
    user        = "root"
    script_path = "/root/finalize-cluster-%RAND%.sh"
  }

  provisioner "file" {
    content = templatefile("${path.module}/templates/create-cluster.sh.tmpl", {
      bastion_address = cidrhost(local.subnet, 2),
    })
    destination = "/root/create-cluster.sh"
  }

  provisioner "remote-exec" {
    inline = ["/bin/sh /root/create-cluster.sh"]
  }
}
