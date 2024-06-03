output "ssh_private_key" {
  description = "The private key for the SSH keypair"
  value       = module.ssh.ssh_private_key
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
  description = "Reserved IP for cluster virtal IP"
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
