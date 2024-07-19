module "nutanix_cluster" {
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
    module.nutanix_cluster
  ]
  vlan_id = local.vlan_id
}

resource "equinix_metal_device" "ad_server" {
  depends_on = [
    module.nutanix_cluster,
    data.equinix_metal_vlan.nutanix
  ]

  operating_system    = "windows_2022"
  project_id          = local.project_id
  hostname            = "ad-server"
  plan                = "c3.small.x86"
  metro               = var.metal_metro
  project_ssh_key_ids = [module.nutanix_cluster.ssh_key_id]

  user_data = templatefile("${path.module}/ad-userdata.tmpl", {
    vxlan       = local.vxlan
    domain      = var.ad_domain
    user        = var.ad_admin_user
    ad_password = var.ad_password
  })
}

resource "equinix_metal_port" "ad_server_bond0" {
  port_id  = [for p in equinix_metal_device.ad_server.ports : p.id if p.name == "bond0"][0]
  layer2   = false
  bonded   = true
  vlan_ids = [local.vlan_id]
}

resource "null_resource" "bastion_ssh" {
  depends_on = [equinix_metal_device.ad_server]

  connection {
    host        = module.nutanix_cluster.bastion_public_ip
    private_key = chomp(module.nutanix_cluster.ssh_private_key_contents)
    type        = "ssh"
    user        = "root"
  }

  provisioner "file" {
    destination = "/root/configure-ad.sh"
    content = templatefile("${path.module}/configure-ad.sh.tmpl", {
      PRISM_IP         = module.nutanix_cluster.cvim_ip_address
      PRISM_USERNAME   = "admin"
      DEFAULT_PASSWORD = "Nutanix/4u)"
      NEW_PASSWORD     = var.new_prism_password
      AD_DOMAIN        = var.ad_domain
      AD_DOMAIN_IP     = equinix_metal_device.ad_server.access_public_ipv4
      AD_USERNAME      = var.ad_admin_user
      AD_PASSWORD      = var.ad_password
    })
  }

  provisioner "remote-exec" {
    inline = ["/bin/bash /root/configure-ad.sh"]
  }
}
