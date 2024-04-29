output "ssh_private_key" {
  description = "The private key for the SSH keypair"
  value       = module.nutanix.ssh_private_key
  sensitive   = false
}

output "bastion_public_ip" {
  description = "The public IP address of the bastion host"
  value       = module.nutanix.bastion_public_ip
}

output "nutanix_sos_hostname" {
  description = "The SOS address to the nutanix machine."
  value       = module.nutanix.nutanix_sos_hostname
}

output "ssh_forward_command" {
  description = "SSH port forward command to use to connect to the Prism GUI"
  value       = module.nutanix.ssh_forward_command
}

output "cvim_ip_address" {
  description = "The IP address of the CVM"
  value       = module.nutanix.cvim_ip_address
}
