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

# module "ssh" {
#   source     = "../../modules/ssh/"
#   project_id = local.project_id
# }

data "equinix_metal_vlan" "nutanix" {
  vlan_id = local.vlan_id
}

resource "equinix_metal_device" "ad-server" {
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

resource "null_resource" "bastion_ssh" {
  depends_on = [equinix_metal_device.ad-server]

  provisioner "local-exec" {
    command = "ssh -L 9440:${module.nutanix-cluster.cvim_ip_address}:9440 -L 19440:${cidrhost(local.subnet, -4)}:9440 -i ${module.nutanix-cluster.ssh_private_key} root@${module.nutanix-cluster.bastion_public_ip} 'bash -s' < ${path.module}/configure-ad.sh"
    environment = {
      PRISM_IP         = module.nutanix-cluster.prism_central_ip_address
      CVM_IP_ADDRESS = module.nutanix-cluster.cvim_ip_address
      PRIVATE_KEY = module.nutanix-cluster.ssh_private_key
      BASTION_PUBLIC_KEY = module.nutanix-cluster.bastion_public_ip
      PRISM_USER       = "admin"
      PRISM_PASSWORD   = "Nutanix/4u)"
      AD_DOMAIN        = equinix_metal_device.ad-server.access_public_ipv4
      AD_USERNAME      = "admin"
      AD_PASSWORD      = "Equinix@AD"
    }
  }
}
