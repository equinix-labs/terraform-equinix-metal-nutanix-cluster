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
  default     = ""
  description = "The name of the Metal project in which to deploy the cluster.  If create_project is false and you do not specify a project ID, the project will be looked up by name."
}

variable "metal_project_id" {
  type        = string
  default     = ""
  description = "The ID of the Metal project in which to deploy to cluster.  If create_project is false and you specify a project ID, the metal_project_name variable is not used."
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

variable "create_vlan" {
  type        = bool
  default     = true
  description = "Whether to create a new VLAN for this project."
}
variable "metal_vlan_id" {
  type        = number
  default     = null
  description = "ID of the VLAN you wish to use."
}

variable "nutanix_node_count" {
  description = "The number of Nutanix nodes to create"
  type        = number
  default     = 3
}

variable "nutanix_reservation_ids" {
  description = "Hardware reservation IDs to use for the Nutanix nodes. If specified, the length of this list must be the same as `nutanix_node_count`.  Each item can be a reservation UUID or `next-available`.  If you use reservation UUIDs, make sure that they are in the same metro specified in `metal_metro`."
  type        = list(string)
  default     = []
}
