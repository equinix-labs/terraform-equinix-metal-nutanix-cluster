locals {
  project_id              = var.create_project ? element(equinix_metal_project.nutanix[*].id, 0) : element(data.equinix_metal_project.nutanix[*].id, 0)
  vlan_id                 = var.create_vlan ? element(equinix_metal_vlan.nutanix[*].id, 0) : element(data.equinix_metal_vlan.nutanix[*].id, 0)
  vxlan                   = var.create_vlan ? element(equinix_metal_vlan.nutanix[*].vxlan, 0) : element(data.equinix_metal_vlan.nutanix[*].vxlan, 0)
  vrf_id                  = var.create_vrf ? element(equinix_metal_vrf.nutanix[*].id, 0) : element(data.equinix_metal_vrf.nutanix[*].id, 0)
  nutanix_reservation_ids = { for idx, val in var.nutanix_reservation_ids : idx => val }
  cluster_gateway         = var.cluster_gateway == "" ? cidrhost(var.cluster_subnet, 1) : var.cluster_gateway
}

resource "terraform_data" "input_validation" {
  lifecycle {
    precondition {
      condition     = length(var.nutanix_reservation_ids) == 0 || length(var.nutanix_reservation_ids) == var.nutanix_node_count
      error_message = "`nutanix_reservation_ids` must be empty to use on-demand instance or must have ${var.nutanix_node_count} items to use hardware reservations"
    }
    precondition {
      condition     = var.create_project == false || var.metal_project_name != ""
      error_message = "If `create_project` is true, `metal_project_name` must not be empty"
    }
    precondition {
      condition     = (var.metal_project_name != "" && var.metal_project_id == "") || (var.metal_project_name == "" && var.metal_project_id != "")
      error_message = "One (and only one) of `metal_project_name` or `metal_project_id` is required"
    }
  }
}

resource "equinix_metal_project" "nutanix" {
  count = var.create_project ? 1 : 0
  name  = var.metal_project_name
  # TODO: See https://github.com/equinix/terraform-provider-equinix/issues/732
  # description = "Nutanix cluster proof-of-concept project. See https://deploy.equinix.com/labs/terraform-equinix-metal-nutanix-cluster/ for more information."
  organization_id = var.metal_organization_id
}

data "equinix_metal_project" "nutanix" {
  count      = var.create_project ? 0 : 1
  name       = var.metal_project_name != "" ? var.metal_project_name : null
  project_id = var.metal_project_id != "" ? var.metal_project_id : null
}

module "ssh" {
  source     = "./modules/ssh/"
  project_id = local.project_id
}

resource "equinix_metal_vlan" "nutanix" {
  count       = var.create_vlan ? 1 : 0
  project_id  = local.project_id
  description = var.metal_vlan_description
  metro       = var.metal_metro
}

data "equinix_metal_vlan" "nutanix" {
  count      = var.create_vlan ? 0 : 1
  project_id = local.project_id
  vxlan      = var.metal_vlan_id
}

resource "equinix_metal_device" "bastion" {
  project_id  = local.project_id
  hostname    = "${var.cluster_name}-bastion"
  description = "${var.cluster_name} bastion to access Nutanix nodes and VMs on ${var.cluster_subnet}. Provides NTP, DHCP, and NAT for these nodes and VMs. Deployed with Terraform module terraform-equinix-metal-nutanix-cluster."
  tags        = [var.cluster_name]
  user_data = templatefile("${path.module}/templates/bastion-userdata.tmpl", {
    metal_vlan_id   = local.vxlan,
    address         = cidrhost(var.cluster_subnet, 2),
    netmask         = cidrnetmask(cidrsubnet(var.cluster_subnet, -1, -1)),
    gateway_address = local.cluster_gateway,
    host_dhcp_start = cidrhost(var.cluster_subnet, 3),
    host_dhcp_end   = cidrhost(var.cluster_subnet, 15),
    vm_dhcp_start   = cidrhost(var.cluster_subnet, 16),
    vm_dhcp_end     = cidrhost(var.cluster_subnet, -5),
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
  port_id         = [for p in equinix_metal_device.bastion.ports : p.id if p.name == "bond0"][0]
  layer2          = false
  bonded          = true
  vlan_ids        = [local.vlan_id]
  reset_on_delete = true
}

# This generates a random suffix to avoid VRF name
# collisions when multiple clusters are deployed to
# an existing Metal project
resource "random_string" "vrf_name_suffix" {
  length  = 5
  special = false
}

resource "equinix_metal_vrf" "nutanix" {
  count       = var.create_vrf ? 1 : 0
  description = "VRF with ASN 65000 and a pool of address space that includes ${var.cluster_subnet}. Deployed with Terraform module terraform-equinix-metal-nutanix-cluster."
  name        = "${var.cluster_name}-vrf-${random_string.vrf_name_suffix.result}"
  metro       = var.metal_metro
  local_asn   = "65000"
  ip_ranges   = [var.cluster_subnet]
  project_id  = local.project_id
}

data "equinix_metal_vrf" "nutanix" {
  count  = var.create_vrf ? 0 : 1
  vrf_id = var.vrf_id
}

resource "equinix_metal_reserved_ip_block" "nutanix" {
  description = "${var.cluster_name} VRF Reserved IP block (${var.cluster_subnet}). Deployed with Terraform module terraform-equinix-metal-nutanix-cluster."
  tags        = [var.cluster_name]
  project_id  = local.project_id
  metro       = var.metal_metro
  type        = "vrf"
  vrf_id      = local.vrf_id
  cidr        = split("/", var.cluster_subnet)[1]
  network     = cidrhost(var.cluster_subnet, 0)
}

resource "equinix_metal_gateway" "gateway" {
  project_id        = local.project_id
  vlan_id           = local.vlan_id
  ip_reservation_id = equinix_metal_reserved_ip_block.nutanix.id
}

resource "equinix_metal_device" "nutanix" {
  count            = var.nutanix_node_count
  project_id       = local.project_id
  hostname         = "${var.cluster_name}-node-${count.index + 1}"
  description      = "${var.cluster_name} node ${count.index + 1}/${var.nutanix_node_count}. Deployed with Terraform module terraform-equinix-metal-nutanix-cluster."
  operating_system = var.metal_nutanix_os
  plan             = var.metal_nutanix_plan
  metro            = var.metal_metro

  hardware_reservation_id          = lookup(local.nutanix_reservation_ids, count.index, null)
  wait_for_reservation_deprovision = length(var.nutanix_reservation_ids) > 0

  ip_address {
    type = "private_ipv4"
  }

}

resource "null_resource" "wait_for_firstboot" {
  depends_on = [equinix_metal_port.bastion_bond0]
  count      = var.nutanix_node_count

  connection {
    bastion_host        = equinix_metal_device.bastion.access_public_ipv4
    bastion_user        = "root"
    bastion_private_key = chomp(module.ssh.ssh_private_key_contents)
    type                = "ssh"
    user                = "root"
    host                = equinix_metal_device.nutanix[count.index].access_private_ipv4
    password            = "nutanix/4u"
    script_path         = "/root/firstboot-check-%RAND%.sh"
    agent               = false
  }

  provisioner "remote-exec" {
    script = "${path.module}/scripts/firstboot-check.sh"
  }
}

resource "equinix_metal_port" "nutanix" {
  depends_on      = [null_resource.wait_for_firstboot]
  count           = var.nutanix_node_count
  port_id         = [for p in equinix_metal_device.nutanix[count.index].ports : p.id if p.name == "bond0"][0]
  layer2          = true
  bonded          = true
  vlan_ids        = [local.vlan_id]
  reset_on_delete = true
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
  count = var.skip_cluster_creation ? 0 : 1

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
      bastion_address = cidrhost(var.cluster_subnet, 2),
    })
    destination = "/root/create-cluster.sh"
  }

  provisioner "remote-exec" {
    inline = ["/bin/sh /root/create-cluster.sh"]
  }
}

resource "null_resource" "get_cvm_ip" {
  count = var.skip_cluster_creation ? 0 : 1

  depends_on = [
    null_resource.finalize_cluster
  ]
  provisioner "local-exec" {
    command = "scp -i ${module.ssh.ssh_private_key} -o StrictHostKeyChecking=no root@${equinix_metal_device.bastion.access_public_ipv4}:/root/cvm_ip_address.txt ${path.module}/cvm_ip_address.txt"
  }
}

data "local_file" "cvm_ip_address" {
  depends_on = [null_resource.get_cvm_ip]
  filename   = "${path.module}/cvm_ip_address.txt"
}