output "ssh_forward_command" {
  description = "SSH port forward command to use to connect to the Prism GUI"
  value       = module.nutanix-cluster.ssh_forward_command
}

output "prism_central_ip_address" {
  description = "Reserved IP for Prism Central VM"
  value       = module.nutanix-cluster.prism_central_ip_address
}

output "bastion_public_ip" {
  description = "The public IP address of the bastion host"
  value       = module.nutanix-cluster.bastion_public_ip
}

output "ad_server_ip" {
  value = equinix_metal_device.ad-server.access_public_ipv4
}