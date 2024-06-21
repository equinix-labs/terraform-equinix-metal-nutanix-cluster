variable "metal_auth_token" {
  type        = string
  sensitive   = true
  description = "Equinix Metal API token."
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

variable "metal_metro" {
  type        = string
  description = "The metro to create the cluster in."
}

variable "create_project" {
  type        = bool
  default     = true
  description = "(Optional) to use an existing project matching `metal_project_name`, set this to false."
}

variable "nutanix_node_count" {
  type        = number
  default     = 2
  description = "The number of Nutanix nodes to create."
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

variable "metal_organization_id" {
  type        = string
  default     = null
  description = "The ID of the Metal organization in which to create the project if `create_project` is true."
}

variable "metal_subnet" {
  type        = string
  default     = "192.168.96.0/21"
  description = "Nutanix cluster subnet."
}

variable "metal_vlan_description" {
  type        = string
  default     = "ntnx-demo"
  description = "Description to add to created VLAN."
}

variable "create_vrf" {
  type        = bool
  default     = true
  description = "Whether to create a new VRF for this project."
}

variable "vrf_id" {
  type        = string
  default     = null
  description = "ID of the VRF you wish to use."
}

variable "metal_nutanix_plan" {
  type        = string
  default     = "c3.small.x86"
  description = "The plan to use for the Nutanix nodes."
}

variable "skip_cluster_creation" {
  type        = bool
  default     = false
  description = "Skip the creation of the Nutanix cluster."
}

variable "metal_bastion_plan" {
  type        = string
  default     = "t3.small.x86"
  description = "The plan to use for the bastion host."
}

variable "metal_nutanix_os" {
  type        = string
  default     = "ubuntu_20_04"
  description = "The operating system to use for the Nutanix nodes."
}

variable "cluster_subnet" {
  type        = string
  default     = "192.168.100.0/22"
  description = "nutanix cluster subnet"
}

