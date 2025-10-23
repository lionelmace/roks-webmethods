
variable "postgresql_version" {
  type        = string
  description = "Version of the postgresql instance. If no value passed, the current ICD preferred version is used."
  default     = null
}

variable "service_endpoints" {
  type        = string
  description = "The type of endpoint of the database instance. Possible values: `public`, `private`, `public-and-private`."
  default     = "public"

  validation {
    condition     = can(regex("^(public|public-and-private|private)$", var.service_endpoints))
    error_message = "Valid values for service_endpoints are 'public', 'public-and-private', and 'private'"
  }
}

variable "member_host_flavor" {
  type        = string
  description = "The host flavor per member. [Learn more](https://registry.terraform.io/providers/IBM-Cloud/ibm/latest/docs/resources/database#host_flavor)."
  default     = "multitenant"
  # Validation is done in the Terraform plan phase by the IBM provider, so no need to add extra validation here.
}

variable "read_only_replicas_count" {
  type        = number
  description = "Number of read-only replicas per leader"
  default     = 1
  validation {
    condition = alltrue([
      var.read_only_replicas_count >= 1,
      var.read_only_replicas_count <= 5
    ])
    error_message = "There is a limit of five read-only replicas per leader"
  }
}