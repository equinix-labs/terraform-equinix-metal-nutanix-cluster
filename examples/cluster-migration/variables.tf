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
  default     = 1
  description = "The number of Nutanix nodes to create. This must be an odd number."
  validation {
    condition     = var.nutanix_node_count % 2 == 1
    error_message = "The number of Nutanix nodes must be an odd number."
  }
}
# tflint-ignore: terraform_unused_declarations
variable "create_vlan" {
  type        = bool
  default     = true
  description = "Whether to create a new VLAN for this project."
}
# tflint-ignore: terraform_unused_declarations
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
  description = "IP pool for all Nutanix Clusters in the example. One bit will be appended to the end and divided between example clusters. (192.168.96.0/21 will result in clusters with ranges 192.168.96.0/22 and 192.168.100.0/22)"
}

variable "metal_nutanix_os" {
  type        = string
  default     = "nutanix_lts_6_5"
  description = "The Equinix Metal OS to use for the Nutanix nodes. nutanix_lts_6_5 is available for Nutanix certified hardware reservation instances. nutanix_lts_6_5_poc may be available upon request."
}


variable "nutanix_reservation_ids" {
  type = object({
    cluster_a = list(string)
    cluster_b = list(string)
  })
  default     = { cluster_a = [], cluster_b = [] }
  description = <<EOT
  Hardware reservation IDs to use for the Nutanix nodes. If specified, the length of this list must
  be the same as `nutanix_node_count` for each cluster.  Each item can be a reservation UUID or `next-available`. If
  you use reservation UUIDs, make sure that they are in the same metro specified in `metal_metro`.
  EOT
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
