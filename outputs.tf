output "ssh_private_key" {
  description = "The private key for the SSH keypair"
  value       = module.ssh.ssh_private_key
  sensitive   = false
}

output "ssh_private_key_contents" {
  description = "The private key contents for the SSH keypair"
  value       = module.ssh.ssh_private_key_contents
  sensitive   = false
}

output "ssh_key_id" {
  description = "The ssh key Id for the SSH keypair"
  value       = module.ssh.equinix_metal_ssh_key_id
  sensitive   = false
}

output "bastion_public_ip" {
  description = "The public IP address of the bastion host"
  value       = equinix_metal_device.bastion.access_public_ipv4
}

output "nutanix_sos_hostname" {
  description = "The SOS address to the nutanix machine."
  value       = equinix_metal_device.nutanix[*].sos_hostname
}

output "ssh_forward_command" {
  description = "SSH port forward command to use to connect to the Prism GUI"
  value       = "ssh -L 9440:${data.local_file.cvm_ip_address.content}:9440 -L 19440:${cidrhost(var.cluster_subnet, -4)}:9440 -i ${module.ssh.ssh_private_key} root@${equinix_metal_device.bastion.access_public_ipv4}"
}

output "cvim_ip_address" {
  description = "The IP address of the CVM"
  value       = data.local_file.cvm_ip_address.content
}

output "virtual_ip_address" {
  description = "Reserved IP for cluster virtual IP"
  value       = cidrhost(var.cluster_subnet, -2)
}

output "iscsi_data_services_ip" {
  description = "Reserved IP for cluster ISCSI Data Services IP"
  value       = cidrhost(var.cluster_subnet, -3)
}

output "prism_central_ip_address" {
  description = "Reserved IP for Prism Central VM"
  value       = cidrhost(var.cluster_subnet, -4)
}

output "nutanix_metal_project_id" {
  description = "Project Id for the nutanix cluster"
  value       = local.project_id
}

output "nutanix_metal_vlan_id" {
  description = "VLan Id for the nutanix cluster"
  value       = local.vlan_id
}

output "cluster_gateway" {
  description = "The Nutanix cluster gateway IP"
  value       = local.cluster_gateway
}
