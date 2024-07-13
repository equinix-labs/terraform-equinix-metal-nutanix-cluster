# Nutanix Cluster on Equinix Metal

This Terraform module will deploy a proof-of-concept demonstrative Nutanix Cluster in Layer 2 isolation on Equinix Metal. DNS, DHCP, and Cluster internet access is managed by an Ubuntu 22.04 bastion/gateway node.

## Acronyms and Terms

- AOS: Acropolis Operating System
- NOS: Nutanix Operating System (Used interchangeably with AOS)
- AHV: AOS Hypervisor
- Phoenix: The AOS/NOS Installer
- CVM: Cluster Virtual Machine
- Prism: AOS Cluster Web UI

## Nutanix Installation in a Nutshell

For those who are unfamiliar with Nutanix. Nutanix is HCI (Hyperconverged Infrastructure) software. See [https://www.nutanix.com/products/nutanix-cloud-infrastructure](https://www.nutanix.com/products/nutanix-cloud-infrastructure) for more details from Nutanix.

Nutanix AOS is typically deployed in a private network without public IPs assigned directly to the host.
This experience differs from what many cloud users would expect in an OS deployment.

This POC Terraform module is inspired by the [Deploying a multi-node Nutanix cluster on Metal](https://deploy.equinix.com/developers/guides/deploying-a-multi-node-nutanix-cluster-on-equinix-metal/) guide which goes into detail about how to deploy Nutanix and the required networking configuration on Equinix Metal. Follow that guide for step-by-step instructions that you can customize along the way.

By deploying this POC Terraform module, you will get an automated and opinionated minimal Nutanix Cluster that will help provide a quick introduction to the platform's capabilities.

This project is NOT intended to demonstrate best practices or Day-2 operations, including security, scale, monitoring, and disaster recovery.

To accommodate deployment requirements, this module will create:

- 1x [m3.small.x86](https://deploy.equinix.com/product/servers/m3-small/) node running [Ubuntu 22.04](https://deploy.equinix.com/developers/docs/metal/operating-systems/supported/#ubuntu) in a [hybrid-bonded networking mode](https://deploy.equinix.com/developers/docs/metal/layer2-networking/hybrid-bonded-mode/)

  This "bastion" node will act as a router and jump box. DHCP, DNS, and NAT (internet access) functionality will be provided by [`dnsmasq`](https://dnsmasq.org/doc.html).

- 3x [m3.large.x86](https://deploy.equinix.com/product/servers/m3-large/) nodes running [Nutanix LTS 6.5](https://deploy.equinix.com/developers/docs/metal/operating-systems/licensed/#nutanix-cloud-platform-on-equinix-metal) in [layer2-bonded networking mode](https://deploy.equinix.com/developers/docs/metal/layer2-networking/layer2-bonded-mode/)

  [Workload Optimized](https://deploy.equinix.com/developers/docs/metal/hardware/workload-optimized-plans/) [hardware reservations](https://deploy.equinix.com/developers/docs/metal/deploy/reserved/) are preferred and required for [capacity](https://deploy.equinix.com/developers/docs/metal/locations/capacity/) and to ensure hardware compatibility with Nutanix. On-demand instances will be deployed by default, see ["On-Demand Instances"](#on-demand-instances) notes below for more details.

- 1x [VLAN](https://deploy.equinix.com/developers/docs/metal/layer2-networking/vlans/) and [Metal Gateway](https://deploy.equinix.com/developers/docs/metal/layer2-networking/metal-gateway/) with [VRF](https://deploy.equinix.com/developers/docs/metal/layer2-networking/vrf/)

  The VRF will route a `/22` IP range within the VLAN, providing ample IP space for POC purposes.

  The bastion node will attach to this VLAN, and the Nutanix nodes will passively access this as their [Native VLAN](https://deploy.equinix.com/developers/docs/metal/layer2-networking/native-vlan/) with DHCP addresses from the VRF space assigned by the bastion node.

- 1x [SSH Key](https://deploy.equinix.com/developers/docs/metal/identity-access-management/ssh-keys/) configured to access the bastion node

  Terraform will create an SSH key scoped to this deployment. The key will be stored in the Terraform workspace.

- 1x [Metal Project](https://deploy.equinix.com/developers/docs/metal/projects/creating-a-project/)

  Optionally deploy a new project to test the POC in isolation or deploy it within an existing project.

## Terraform installation

You'll need [Terraform installed](https://developer.hashicorp.com/terraform/install) and an [Equinix Metal account](https://deploy.equinix.com/developers/docs/metal/identity-access-management/users/) with an [API key](https://deploy.equinix.com/developers/docs/metal/identity-access-management/api-keys/).

If you have the [Metal CLI](https://deploy.equinix.com/developers/docs/metal/libraries/cli/) configured, the following will setup your authentication and project settings in an OSX or Linux shell environment.

```sh
eval $(metal env -o terraform --export) #
export TF_VAR_metal_metro=sl # Deploy to Seoul
```

Otherwise, copy `terraform.tfvars.example` to `terraform.tfvars` and edit the input values before continuing.

Run the following from your console terminal:

```sh
terraform init
terraform apply
```

When complete, after roughly 45m, you'll see something like the following:

```console
Outputs:

bastion_public_ip = "ipv4-address"
nutanix_sos_hostname = [
  "uuid1@sos.sl1.platformequinix.com",
  "uuid2@sos.sl1.platformequinix.com",
  "uuid3@sos.sl1.platformequinix.com",
]
ssh_private_key = "/terraform/workspace/ssh-key-abc123"
ssh_forward_command = "ssh -L 9440:1.2.3.4:9440 -i /terraform/workspace/ssh-key-abc123 root@ipv4-address"
```

See ["Known Problems"](#known-problems) if your `terraform apply` does not complete successfully.

## Next Steps

You have several ways to access the bastion node, Nutanix nodes, and the cluster.

### Login to Prism GUI

- First create an SSH port forward session with the bastion host:

  **Mac or Linux**

  ```sh
  $(terraform output -raw ssh_forward_command)
  ```

  **Windows**

  ```sh
  invoke-expression $(terraform output -raw ssh_forward_command)
  ```

- Then open a browser and navigate to <https://localhost:9440> (the certificate will not match the domain)
- See [Logging Into Prism Central](https://portal.nutanix.com/page/documents/details?targetId=Prism-Central-Guide-vpc_2023_4:mul-login-pc-t.html) for more details (including default credentials)

### Access the Bastion host over SSH

For access to the bastion node, for troubleshooting the installation or to for network access to the Nutanix nodes, you can SSH into the bastion host using:

```sh
ssh -i $(terraform output -raw ssh_private_key) root@$(terraform output -raw bastion_public_ip)
```

### Access the Nutanix nodes over SSH

You can open a direct SSH session to the Nutanix nodes using the bastion host as a jumpbox. Debug details from the Cluster install can be found within `/home/nutanix/data/logs`.

```sh
ssh -i $(terraform output -raw ssh_private_key) -j root@$(terraform output -raw bastion_public_ip) nutanix@$(terraform output -raw cvim_ip_address)
```

### Access the Nutanix nodes out-of-band

You can access use the [SOS (Serial-Over-SSH)](https://deploy.equinix.com/developers/docs/metal/resilience-recovery/serial-over-ssh/) interface for [out-of-bands access using the default credentials for Nutanix nodes](https://deploy.equinix.com/developers/docs/metal/operating-systems/licensed/#accessing-your-nutanix-server).

```sh
ssh -i $(terraform output -raw ssh_private_key) $(terraform output -raw nutanix_sos_hostname[0]) # access the first node
ssh -i $(terraform output -raw ssh_private_key) $(terraform output -raw nutanix_sos_hostname[1]) # access the second node
ssh -i $(terraform output -raw ssh_private_key) $(terraform output -raw nutanix_sos_hostname[2]) # access the third node
```

## Known Problems

### On-Demand Instances

This POC allocates a [m3.small.x86](https://deploy.equinix.com/product/servers/m3-small/) node for the Bastion host by default, you can change this to another instance type of your choosing by setting the `metal_bastion_plan` variable.

This POC allocates [m3.large.x86](https://deploy.equinix.com/product/servers/m3-large/) instances for the Nutanix nodes. Not all on-demand m3.large.x86 nodes will work. At the time of writing, we recommend the SL or AM Metros for deployment. If a Nutanix node fails to provision, please try to `terraform apply` again. A node that fails to provision with the Nutanix AOS will be automatically removed from your project. Terraform will subsequently attempt to replace those servers.

Production deployments should use qualified [Workload Optimized](https://deploy.equinix.com/developers/docs/metal/hardware/workload-optimized-plans/) instances for Nutanix nodes. Create a [hardware reservation](https://deploy.equinix.com/developers/docs/metal/deploy/reserved/) or [contact Equinix Metal](https://deploy.equinix.com/support/) to obtain validated [Nutanix compatible servers](https://deploy.equinix.com/developers/os-compatibility/). You can also [convert a successfully deployed on-demand instance to a hardware reservation](https://deploy.equinix.com/developers/docs/metal/deploy/reserved/#converting-on-demand-to-a-hardware-reservation). Hardware Reservations will ensure that you get the correct hardware for your Nutanix deployments.

### SSH failures while running on macOS

The Nutanix devices have `sshd` configured with `MaxSessions 1`. In most cases this is not a problem, but in our testing on macOS we observed frequent SSH connection errors. These connection errors can be resolved by turning off the SSH agent in your terminal before running `terraform apply`. To turn off your SSH agent in a macOS terminal, run `unset SSH_AUTH_SOCK`.

Error messages that match this problem:

- `Error chmodding script file to 0777 in remote machine: ssh: rejected: administratively prohibited (open failed)`

### VLAN Cleanup Failure

During the execution of a Terraform destroy operation, the deletion of a VLAN may fail with an HTTP 422 Unprocessable Entity response. The debug logs indicate that the DELETE request to remove the VLAN was sent successfully, but the response from the Equinix Metal API indicated a failure to process the request. The specific VLAN identified by the ID "xxxx" could not be deleted.

**Fix:**

If you encounter this issue, re-run the `terraform destroy` command to clean up the resources.

```sh
terraform destroy
```

### Other Timeouts and Connection issues

This POC project has not ironed out all potential networking and provisioning timing hiccups that can occur. In many situations, running `terraform apply` again will progress the deployment to the next step. If you do not see progress after 3 attempts, open an issue on GitHub: <https://github.com/equinix-labs/terraform-equinix-metal-nutanix-cluster/issues/new>.

## Examples

To view examples for how you can leverage this module, please see the [examples](examples/) directory.

<!-- TEMPLATE: The following block has been generated by terraform-docs util: https://github.com/terraform-docs/terraform-docs -->
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_equinix"></a> [equinix](#requirement\_equinix) | >= 1.30 |
| <a name="requirement_local"></a> [local](#requirement\_local) | >= 2.5 |
| <a name="requirement_null"></a> [null](#requirement\_null) | >= 3 |
| <a name="requirement_random"></a> [random](#requirement\_random) | >= 3 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_equinix"></a> [equinix](#provider\_equinix) | >= 1.30 |
| <a name="provider_local"></a> [local](#provider\_local) | >= 2.5 |
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
| [null_resource.get_cvm_ip](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.reboot_nutanix](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_dhcp](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [null_resource.wait_for_firstboot](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [random_string.vrf_name_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) | resource |
| [terraform_data.input_validation](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [equinix_metal_project.nutanix](https://registry.terraform.io/providers/equinix/equinix/latest/docs/data-sources/metal_project) | data source |
| [equinix_metal_vlan.nutanix](https://registry.terraform.io/providers/equinix/equinix/latest/docs/data-sources/metal_vlan) | data source |
| [equinix_metal_vrf.nutanix](https://registry.terraform.io/providers/equinix/equinix/latest/docs/data-sources/metal_vrf) | data source |
| [local_file.cvm_ip_address](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_metal_auth_token"></a> [metal\_auth\_token](#input\_metal\_auth\_token) | Equinix Metal API token. | `string` | n/a | yes |
| <a name="input_metal_metro"></a> [metal\_metro](#input\_metal\_metro) | The metro to create the cluster in. | `string` | n/a | yes |
| <a name="input_cluster_gateway"></a> [cluster\_gateway](#input\_cluster\_gateway) | The cluster gateway IP address | `string` | `""` | no |
| <a name="input_cluster_subnet"></a> [cluster\_subnet](#input\_cluster\_subnet) | nutanix cluster subnet | `string` | `"192.168.100.0/22"` | no |
| <a name="input_create_project"></a> [create\_project](#input\_create\_project) | (Optional) to use an existing project matching `metal_project_name`, set this to false. | `bool` | `true` | no |
| <a name="input_create_vlan"></a> [create\_vlan](#input\_create\_vlan) | Whether to create a new VLAN for this project. | `bool` | `true` | no |
| <a name="input_create_vrf"></a> [create\_vrf](#input\_create\_vrf) | Whether to create a new VRF for this project. | `bool` | `true` | no |
| <a name="input_metal_bastion_plan"></a> [metal\_bastion\_plan](#input\_metal\_bastion\_plan) | Which plan to use for the bastion host. | `string` | `"m3.small.x86"` | no |
| <a name="input_metal_nutanix_os"></a> [metal\_nutanix\_os](#input\_metal\_nutanix\_os) | Which OS to use for the Nutanix nodes. | `string` | `"nutanix_lts_6_5"` | no |
| <a name="input_metal_nutanix_plan"></a> [metal\_nutanix\_plan](#input\_metal\_nutanix\_plan) | Which plan to use for the Nutanix nodes (must be Nutanix compatible, see https://deploy.equinix.com/developers/os-compatibility/) | `string` | `"m3.large.x86"` | no |
| <a name="input_metal_organization_id"></a> [metal\_organization\_id](#input\_metal\_organization\_id) | The ID of the Metal organization in which to create the project if `create_project` is true. | `string` | `null` | no |
| <a name="input_metal_project_id"></a> [metal\_project\_id](#input\_metal\_project\_id) | The ID of the Metal project in which to deploy to cluster. If `create_project` is false and<br>  you do not specify a project name, the project will be looked up by ID. One (and only one) of<br>  `metal_project_name` or `metal_project_id` is required or `metal_project_id` must be set. | `string` | `""` | no |
| <a name="input_metal_project_name"></a> [metal\_project\_name](#input\_metal\_project\_name) | The name of the Metal project in which to deploy the cluster. If `create_project` is false and<br>  you do not specify a project ID, the project will be looked up by name. One (and only one) of<br>  `metal_project_name` or `metal_project_id` is required or `metal_project_id` must be set.<br>  Required if `create_project` is true. | `string` | `""` | no |
| <a name="input_metal_vlan_description"></a> [metal\_vlan\_description](#input\_metal\_vlan\_description) | Description to add to created VLAN. | `string` | `"ntnx-demo"` | no |
| <a name="input_metal_vlan_id"></a> [metal\_vlan\_id](#input\_metal\_vlan\_id) | ID of the VLAN you wish to use. | `number` | `null` | no |
| <a name="input_nutanix_node_count"></a> [nutanix\_node\_count](#input\_nutanix\_node\_count) | The number of Nutanix nodes to create. | `number` | `3` | no |
| <a name="input_nutanix_reservation_ids"></a> [nutanix\_reservation\_ids](#input\_nutanix\_reservation\_ids) | Hardware reservation IDs to use for the Nutanix nodes. If specified, the length of this list must<br>  be the same as `nutanix_node_count`.  Each item can be a reservation UUID or `next-available`. If<br>  you use reservation UUIDs, make sure that they are in the same metro specified in `metal_metro`. | `list(string)` | `[]` | no |
| <a name="input_skip_cluster_creation"></a> [skip\_cluster\_creation](#input\_skip\_cluster\_creation) | Skip the creation of the Nutanix cluster. | `bool` | `false` | no |
| <a name="input_vrf_id"></a> [vrf\_id](#input\_vrf\_id) | ID of the VRF you wish to use. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_bastion_public_ip"></a> [bastion\_public\_ip](#output\_bastion\_public\_ip) | The public IP address of the bastion host |
| <a name="output_cluster_gateway"></a> [cluster\_gateway](#output\_cluster\_gateway) | The Nutanix cluster gateway IP |
| <a name="output_cvim_ip_address"></a> [cvim\_ip\_address](#output\_cvim\_ip\_address) | The IP address of the CVM |
| <a name="output_iscsi_data_services_ip"></a> [iscsi\_data\_services\_ip](#output\_iscsi\_data\_services\_ip) | Reserved IP for cluster ISCSI Data Services IP |
| <a name="output_nutanix_sos_hostname"></a> [nutanix\_sos\_hostname](#output\_nutanix\_sos\_hostname) | The SOS address to the nutanix machine. |
| <a name="output_prism_central_ip_address"></a> [prism\_central\_ip\_address](#output\_prism\_central\_ip\_address) | Reserved IP for Prism Central VM |
| <a name="output_ssh_forward_command"></a> [ssh\_forward\_command](#output\_ssh\_forward\_command) | SSH port forward command to use to connect to the Prism GUI |
| <a name="output_ssh_private_key"></a> [ssh\_private\_key](#output\_ssh\_private\_key) | The private key for the SSH keypair |
| <a name="output_virtual_ip_address"></a> [virtual\_ip\_address](#output\_virtual\_ip\_address) | Reserved IP for cluster virtal IP |
<!-- END_TF_DOCS -->

## Contributing

If you would like to contribute to this module, see [CONTRIBUTING](CONTRIBUTING.md) page.

## License

Apache License, Version 2.0. See [LICENSE](LICENSE).
