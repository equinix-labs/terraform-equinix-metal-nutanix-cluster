output "ssh_private_key" {
  description = "The private key for the SSH keypair"
  value       = tls_private_key.ssh_key.private_key_pem
  sensitive   = true
}

output "bastion_public_ip" {
  description = "The public IP address of the bastion host"
  value       = equinix_metal_device.bastion.access_public_ipv4
}
