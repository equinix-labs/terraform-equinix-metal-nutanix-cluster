variable "metal_auth_token" {
  type        = string
  description = "Your Equinix Metal API Token"
}

variable "metal_vlan_description" {
  type        = string
  default     = "ntnx-demo"
  description = "Description added to VLAN created for your Nutanix Cluster"
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
