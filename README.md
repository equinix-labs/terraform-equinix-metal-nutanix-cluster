# Nutanix Cluster on Equinix Metal

This Terraform module will deploy a demonstrative Nutanix Cluster in Layer 2 isolation on Equinix Metal. The cluster IPAM and Internet Access is managed by a Rocky bastion/gateway node.

## Acronyms and Terms

* AOS: Acropolis Operating System
* NOS: Nutanix Operating System (Used interchangably with AOS)
* AHV: AOS Hypervisor
* Phoenix: The AOS/NOS Installer
* CVM: Cluster Virtual Machine
* Prism: AOS Cluster Web UI

## Nutanix Installation in a nutshell

For those who are unfamiliar with Nutanix. Nutanix is a virtual machine management suite, similar to VMWare ESXi.

Nutanix is typically deployed in a private network without public IPs assigned directly to the host.
This experience is different than what many cloud users would expect in an OS deployment.

Due to this, we'll be deploying Nutanix with only private management IPs and later converting the nodes to full Layer-2.

To allow access to the internet and make it easier to access these hosts, we'll be deploying a server in Hybrid networking mode to act as a router and jump box.

To begin, we'll start by provisioning a c3.small which has two NICs. Allowing us to have one in layer-3 with a public IP,
and one in layer-2 to access the internal layer-2 network.

## Manual Installation

See [INSTALL_GUIDE.md](INSTALL_GUIDE.md) to install by hand. Otherwise, skip to the following section to let Terraform do all the work.

## Terraform installation

```sh
terraform init
eval $(metal env -o terraform --export)
terraform apply
```

### Note: SSH failures while running on macOS

The Nutanix devices have `sshd` configured with `MaxSessions 1`.  In most cases this is not a problem, but in our testing on macOS we observed frequent SSH connection errors.  These connection errors can be resolved by turning off the SSH agent in your terminal before running `terraform apply`.  To turn off your SSH agent in a macOS terminal, run `unset SSH_AUTH_SOCK`.

### Login

```sh
touch nutanix_rsa
chmod 0600 nutanix_rsa
terraform output -raw ssh_private_key > nutanix_rsa
ssh -i nutanix_rsa root@$(terraform output -raw bastion_public_ip)
```

## Examples

To view examples for how you can leverage this module, please see the [examples](examples/) directory.

<!-- TEMPLATE: The following block has been generated by terraform-docs util: https://github.com/terraform-docs/terraform-docs -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_equinix"></a> [equinix](#requirement\_equinix) | >= 1.30 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_equinix"></a> [equinix](#provider\_equinix) | >= 1.30 |
| <a name="provider_null"></a> [null](#provider\_null) | >= 3 |
| <a name="provider_random"></a> [random](#provider\_random) | >= 3 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ssh"></a> [ssh](#module\_ssh) | ./modules/ssh/ | n/a |

## Resources

| Name | Type |
|------|------|
| [equinix_metal_device.bastion](https://registry.terraform.io/providers/equinix/equinix/latest/docs/resources/metal_device) | resource |
| [equinix_metal_device.nutanix](https://registry.terraform.io/providers/equinix/equinix/latest/docs/resources/metal_device) | resource |
| [equinix_metal_gateway.gateway](https://registry.terraform.io/providers/equinix/equinix/latest/docs/resources/metal_gateway) | resource |
| [equinix_metal_port.bastion_bond0](https://registry.terraform.io/providers/equinix/equinix/latest/docs/resources/metal_port) | resource |
| [equinix_metal_port.nutanix](https://registry.terraform.io/providers/equinix/equinix/latest/docs/resources/metal_port) | resource |
| [equinix_metal_project.nutanix](https://registry.terraform.io/providers/equinix/equinix/latest/docs/resources/metal_project) | resource |
| [equinix_metal_reserved_ip_block.nutanix](https://registry.terraform.io/providers/equinix/equinix/latest/docs/resources/metal_reserved_ip_block) | resource |
| [equinix_metal_vlan.nutanix](https://registry.terraform.io/providers/equinix/equinix/latest/docs/resources/metal_vlan) | resource |
| [equinix_metal_vrf.nutanix](https://registry.terraform.io/providers/equinix/equinix/latest/docs/resources/metal_vrf) | resource |
| [null_resource.finalize_cluster](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.reboot_nutanix](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_dhcp](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_firstboot](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_string.vrf_name_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [terraform_data.input_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [equinix_metal_project.nutanix](https://registry.terraform.io/providers/equinix/equinix/latest/docs/data-sources/metal_project) | data source |
| [equinix_metal_vlan.nutanix](https://registry.terraform.io/providers/equinix/equinix/latest/docs/data-sources/metal_vlan) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_metal_auth_token"></a> [metal\_auth\_token](#input\_metal\_auth\_token) | Equinix Metal API token. | `string` | n/a | yes |
| <a name="input_metal_metro"></a> [metal\_metro](#input\_metal\_metro) | The metro to create the cluster in. | `string` | n/a | yes |
| <a name="input_metal_organization_id"></a> [metal\_organization\_id](#input\_metal\_organization\_id) | The ID of the Metal organization in which to create the project if create\_project is true. | `string` | n/a | yes |
| <a name="input_create_project"></a> [create\_project](#input\_create\_project) | (Optional) to use an existing project matching `metal_project_name`, set this to false | `bool` | `true` | no |
| <a name="input_create_vlan"></a> [create\_vlan](#input\_create\_vlan) | Whether to create a new VLAN for this project. | `bool` | `true` | no |
| <a name="input_metal_bastion_plan"></a> [metal\_bastion\_plan](#input\_metal\_bastion\_plan) | Which plan to use for the bastion host. | `string` | `"c3.small.x86"` | no |
| <a name="input_metal_project_id"></a> [metal\_project\_id](#input\_metal\_project\_id) | The ID of the Metal project in which to deploy to cluster.  If create\_project is false and you specify a project ID, the metal\_project\_name variable is not used. | `string` | `""` | no |
| <a name="input_metal_project_name"></a> [metal\_project\_name](#input\_metal\_project\_name) | The name of the Metal project in which to deploy the cluster.  If create\_project is false and you do not specify a project ID, the project will be looked up by name. | `string` | `""` | no |
| <a name="input_metal_vlan_description"></a> [metal\_vlan\_description](#input\_metal\_vlan\_description) | Description to add to created VLAN. | `string` | `"ntnx-demo"` | no |
| <a name="input_metal_vlan_id"></a> [metal\_vlan\_id](#input\_metal\_vlan\_id) | ID of the VLAN you wish to use. | `number` | `null` | no |
| <a name="input_nutanix_node_count"></a> [nutanix\_node\_count](#input\_nutanix\_node\_count) | The number of Nutanix nodes to create | `number` | `3` | no |
| <a name="input_nutanix_reservation_ids"></a> [nutanix\_reservation\_ids](#input\_nutanix\_reservation\_ids) | Hardware reservation IDs to use for the Nutanix nodes. If specified, the length of this list must be the same as `nutanix_node_count`.  Each item can be a reservation UUID or `next-available`.  If you use reservation UUIDs, make sure that they are in the same metro specified in `metal_metro`. | `list(string)` | `[]` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bastion_public_ip"></a> [bastion\_public\_ip](#output\_bastion\_public\_ip) | The public IP address of the bastion host |
| <a name="output_nutanix_sos_hostname"></a> [nutanix\_sos\_hostname](#output\_nutanix\_sos\_hostname) | The SOS address to the nutanix machine. |
| <a name="output_ssh_private_key"></a> [ssh\_private\_key](#output\_ssh\_private\_key) | The private key for the SSH keypair |
<!-- END_TF_DOCS -->
## Contributing

If you would like to contribute to this module, see [CONTRIBUTING](CONTRIBUTING.md) page.

## License

Apache License, Version 2.0. See [LICENSE](LICENSE).
