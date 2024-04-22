variable "metal_auth_token" {
  type        = string
  description = "Equinix Metal API token."
  sensitive   = true
}

variable "metal_vlan_description" {
  type        = string
  description = "Description to add to created VLAN."
  default     = "ntnx-demo"
}

variable "metal_project_name" {
  type        = string
  description = "The name of the Metal project in which to deploy the cluster.  If create_project is false the project will be looked up by name."
}
variable "metal_organization_id" {
  type        = string
  description = "The ID of the Metal organization in which to create the project if create_project is true."
}

variable "metal_metro" {
  type        = string
  description = "The metro to create the cluster in."
}
variable "create_project" {
  type        = bool
  default     = true
  description = "(Optional) to use an existing project matching `metal_project_name`, set this to false"
}

variable "metal_bastion_plan" {
  type        = string
  default     = "c3.small.x86"
  description = "Which plan to use for the bastion host."
}

variable "nutanix_cvm_password" {
  description = "Custom password for changing the Nutanix Controller VM (CVM) default password"
  type        = string
  sensitive   = false
}

variable "nutanix_node_count" {
  description = "The number of Nutanix nodes to create"
  type        = number
  default     = 3
}
