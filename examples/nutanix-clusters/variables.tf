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
