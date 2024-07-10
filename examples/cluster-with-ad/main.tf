module "nutanix-cluster" {
  source = "../.."

  metal_auth_token        = var.metal_auth_token
  metal_metro             = var.metal_metro
  create_project          = var.create_project
  metal_project_id        = var.metal_project_id
  metal_project_name      = var.metal_project_name
  metal_vlan_description  = var.metal_vlan_description
  metal_vlan_id           = var.metal_vlan_id
  create_vlan             = var.create_vlan
  metal_bastion_plan      = var.metal_bastion_plan
  metal_nutanix_os        = var.metal_nutanix_os
  metal_nutanix_plan      = var.metal_nutanix_plan
  metal_organization_id   = var.metal_organization_id
  nutanix_node_count      = var.nutanix_node_count
  nutanix_reservation_ids = var.nutanix_reservation_ids
  skip_cluster_creation   = var.skip_cluster_creation
}

data "equinix_metal_vlan" "nutanix" {
  depends_on = [
    module.nutanix-cluster
  ]
  vlan_id = local.vlan_id
}

resource "equinix_metal_device" "ad-server" {
  depends_on = [
    module.nutanix-cluster,
    data.equinix_metal_vlan.nutanix
  ]

  operating_system    = "windows_2022"
  project_id          = local.project_id
  hostname            = "ad-server"
  plan                = "c3.small.x86"
  metro               = var.metal_metro
  project_ssh_key_ids = [module.nutanix-cluster.ssh_key_id]

  user_data = templatefile("${path.module}/ad-userdata.tmpl", {
    vxlan  = local.vxlan
    domain = local.ad_domain_name
    user   = local.ad_admin_user
  })
}

resource "equinix_metal_port" "ad_server_bond0" {
  port_id  = [for p in equinix_metal_device.ad-server.ports : p.id if p.name == "bond0"][0]
  layer2   = false
  bonded   = true
  vlan_ids = [local.vlan_id]
}

resource "null_resource" "bastion_ssh_1" {
  depends_on = [equinix_metal_device.ad-server]

  connection {
    host        = module.nutanix-cluster.bastion_public_ip
    private_key = chomp(module.nutanix-cluster.ssh_private_key_contents)
    type        = "ssh"
    user        = "root"
  }

  provisioner "file" {
    destination = "/root/configure-ad.sh"
    content = templatefile("${path.module}/configure-ad.sh.tmpl", {
      PRISM_IP           = module.nutanix-cluster.prism_central_ip_address
      PRISM_USER         = "admin"
      PRISM_PASSWORD     = "Nutanix/4u)"
      AD_DOMAIN          = equinix_metal_device.ad-server.access_public_ipv4
      AD_USERNAME        = "admin"
      AD_PASSWORD        = "Equinix@AD"
    })
  }

  provisioner "remote-exec" {
    inline = ["/bin/sh /root/configure-ad.sh"]
  }

#   provisioner "local-exec" {
#     command = "scp -i ${module.ssh.ssh_private_key} -o StrictHostKeyChecking=no root@${equinix_metal_device.bastion.access_public_ipv4}:/root/cvm_ip_address.txt ${path.module}/cvm_ip_address.txt"
#   }
}
