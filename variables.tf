variable "metal_auth_token" {
}

variable "metal_vlan_description" {
  default = "ntnx-demo"
}

variable "metal_project_name" {
  description = "The name of the Metal project in which to deploy the cluster.  If create_project is false the project will be looked up by name."
}

variable "create_project" {
  default = true
  description = "(Optional) to use an existing project matching `metal_project_name`, set this to false"
}
