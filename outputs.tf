output "ssh_private_key" {
  description = "The private key for the SSH keypair"
  value       = module.ssh.ssh_private_key
  sensitive   = false
}

output "bastion_public_ip" {
  description = "The public IP address of the bastion host"
  value       = equinix_metal_device.bastion.access_public_ipv4
}


output "nutanix_private_ip" {
  description = "The private IP assigned to the Nutanix machine"
  value       = equinix_metal_device.nutanix[*].access_private_ipv4
}

output "nutanix_sos_hostname" {
  description = "The SOS address to the nutanix machine."
  value       = equinix_metal_device.nutanix[*].sos_hostname
}
