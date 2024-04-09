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

variable "create_project" {
  type        = bool
  default     = true
  description = "(Optional) to use an existing project matching `metal_project_name`, set this to false"
}
