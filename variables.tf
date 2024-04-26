variable "metal_auth_token" {
  type        = string
  sensitive   = true
  description = "Equinix Metal API token."
}

variable "metal_vlan_description" {
  type        = string
  default     = "ntnx-demo"
  description = "Description to add to created VLAN."
}

variable "metal_project_name" {
  type        = string
  default     = ""
  description = <<EOT
  The name of the Metal project in which to deploy the cluster. If `create_project` is false and
  you do not specify a project ID, the project will be looked up by name. One (and only one) of
  `metal_project_name` or `metal_project_id` is required or `metal_project_id` must be set.
  Required if `create_project` is true.
  EOT
}

variable "metal_project_id" {
  type        = string
  default     = ""
  description = <<EOT
  The ID of the Metal project in which to deploy to cluster. If `create_project` is false and
  you do not specify a project name, the project will be looked up by ID. One (and only one) of
  `metal_project_name` or `metal_project_id` is required or `metal_project_id` must be set.
  EOT
}

variable "metal_organization_id" {
  type        = string
  default     = null
  description = "The ID of the Metal organization in which to create the project if `create_project` is true."
}

variable "metal_metro" {
  type        = string
  description = "The metro to create the cluster in."
}

variable "create_project" {
  type        = bool
  default     = true
  description = "(Optional) to use an existing project matching `metal_project_name`, set this to false."
}

variable "metal_bastion_plan" {
  type        = string
  default     = "m3.small.x86"
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

variable "metal_nutanix_os" {
  type        = string
  default     = "nutanix_lts_6_5"
  description = "Which OS to use for the Nutanix nodes."
}

variable "metal_nutanix_plan" {
  type        = string
  default     = "m3.large.x86"
  description = "Which plan to use for the Nutanix nodes (must be Nutanix compatible, see https://deploy.equinix.com/developers/os-compatibility/)"
}

variable "nutanix_node_count" {
  type        = number
  default     = 3
  description = "The number of Nutanix nodes to create."
}

variable "skip_cluster_creation" {
  type        = bool
  default     = false
  description = "Skip the creation of the Nutanix cluster."
}

variable "nutanix_reservation_ids" {
  type        = list(string)
  default     = []
  description = <<EOT
  Hardware reservation IDs to use for the Nutanix nodes. If specified, the length of this list must
  be the same as `nutanix_node_count`.  Each item can be a reservation UUID or `next-available`. If
  you use reservation UUIDs, make sure that they are in the same metro specified in `metal_metro`.
  EOT
}
