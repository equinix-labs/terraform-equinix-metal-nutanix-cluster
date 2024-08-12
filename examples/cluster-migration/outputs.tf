output "nutanix_cluster1_ssh_private_key" {
  description = "The SSH keypair's private key for cluster1"
  value       = module.nutanix_cluster1.ssh_private_key
}

output "nutanix_cluster2_ssh_private_key" {
  description = "The SSH keypair's private key for cluster1"
  value       = module.nutanix_cluster2.ssh_private_key
}

output "nutanix_cluster1_bastion_public_ip" {
  description = "The public IP address of the bastion host"
  value       = module.nutanix_cluster1.bastion_public_ip
}

output "nutanix_cluster2_bastion_public_ip" {
  description = "The public IP address of the bastion host"
  value       = module.nutanix_cluster2.bastion_public_ip
}

output "nutanix_cluster1_ssh_forward_command" {
  description = "SSH port forward command to use to connect to the Prism GUI"
  value       = "ssh -L 9440:${module.nutanix_cluster1.cvim_ip_address}:9440 -L 19440:${module.nutanix_cluster1.prism_central_ip_address}:9440 -i ${module.nutanix_cluster1.ssh_private_key} root@${module.nutanix_cluster1.bastion_public_ip}"
}

output "nutanix_cluster2_ssh_forward_command" {
  description = "SSH port forward command to use to connect to the Prism GUI"
  value       = "ssh -L 9442:${module.nutanix_cluster2.cvim_ip_address}:9440 -L 19442:${module.nutanix_cluster2.prism_central_ip_address}:9440 -i ${module.nutanix_cluster2.ssh_private_key} root@${module.nutanix_cluster2.bastion_public_ip}"
}

output "nutanix_cluster1_cvim_ip_address" {
  description = "The IP address of the CVM"
  value       = module.nutanix_cluster1.cvim_ip_address
}

output "nutanix_cluster2_cvim_ip_address" {
  description = "The IP address of the CVM"
  value       = module.nutanix_cluster2.cvim_ip_address
}

output "nutanix_cluster1_virtual_ip_address" {
  description = "Reserved IP for cluster virtal IP"
  value       = module.nutanix_cluster1.virtual_ip_address
}

output "nutanix_cluster2_virtual_ip_address" {
  description = "Reserved IP for cluster virtal IP"
  value       = module.nutanix_cluster2.virtual_ip_address
}

output "nutanix_cluster1_iscsi_data_services_ip" {
  description = "Reserved IP for cluster ISCSI Data Services IP"
  value       = module.nutanix_cluster1.iscsi_data_services_ip
}

output "nutanix_cluster2_iscsi_data_services_ip" {
  description = "Reserved IP for cluster ISCSI Data Services IP"
  value       = module.nutanix_cluster2.iscsi_data_services_ip
}

output "nutanix_cluster1_prism_central_ip_address" {
  description = "Reserved IP for Prism Central VM"
  value       = module.nutanix_cluster1.prism_central_ip_address
}

output "nutanix_cluster2_prism_central_ip_address" {
  description = "Reserved IP for Prism Central VM"
  value       = module.nutanix_cluster2.prism_central_ip_address
}

output "nutanix_cluster1_cluster_gateway" {
  description = "The Nutanix cluster gateway IP"
  value       = module.nutanix_cluster1.cluster_gateway
}

output "nutanix_cluster2_cluster_gateway" {
  description = "The Nutanix cluster gateway IP"
  value       = module.nutanix_cluster2.cluster_gateway
}
