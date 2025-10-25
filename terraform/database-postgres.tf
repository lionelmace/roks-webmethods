##############################################################################
# Variables
##############################################################################

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

variable "memory_mb" {
  type        = number
  description = "Allocated memory per member."
}

variable "disk_mb" {
  type        = number
  description = "Allocated disk per member."
}

variable "cpu_count" {
  type        = number
  description = "Allocated dedicated CPU per member. For shared CPU, set to 0"
  default     = 0
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

##############################################################################
# Postgresql
##############################################################################

module "database" {
  source = "terraform-ibm-modules/icd-postgresql/ibm"
  # remove the above line and uncomment the below 2 lines to consume the module from the registry
  # source            = "terraform-ibm-modules/icd-postgresql/ibm"
  # version           = "X.Y.Z" # Replace "X.Y.Z" with a release version to lock into a specific release
  resource_group_id   = module.resource_group.resource_group_id
  name                = "${var.prefix}-data-store"
  region              = var.region
  postgresql_version  = var.postgresql_version
  access_tags         = var.access_tags
  tags                = var.resource_tags
  service_endpoints   = var.service_endpoints
  member_host_flavor  = var.member_host_flavor
  deletion_protection = false
  memory_mb           = var.memory_mb
  disk_mb             = var.disk_mb
  cpu_count           = var.cpu_count
_  service_credential_names = {
    "postgresql_admin" : "Administrator",
    "postgresql_operator" : "Operator",
    "postgresql_viewer" : "Viewer",
    "postgresql_editor" : "Editor",
  }
}

# On destroy, we are seeing that even though the replica has been returned as
# destroyed by terraform, the leader instance destroy can fail with: "You
# must delete all replicas before disabling the leader. Try again with valid
# values or contact support if the issue persists."
# The ICD team have recommended to wait for a period of time after the replica
# destroy completes before attempting to destroy the leader instance, so hence
# adding a time sleep here.

resource "time_sleep" "wait_time" {
  depends_on = [module.database]

  destroy_duration = "5m"
}

##############################################################################
# ICD postgresql read-only-replica
##############################################################################

module "read_only_replica_postgresql_db" {
  count               = var.read_only_replicas_count
  source              = "terraform-ibm-modules/icd-postgresql/ibm"
  resource_group_id   = module.resource_group.resource_group_id
  name                = "${var.prefix}-read-only-replica-${count.index}"
  region              = var.region
  tags                = var.resource_tags
  access_tags         = var.access_tags
  postgresql_version  = var.postgresql_version
  remote_leader_crn   = module.database.crn
  deletion_protection = false
  member_host_flavor  = "multitenant"
  memory_mb           = 4096 # Must be an increment of 384 megabytes. The minimum size of a read-only replica is 2 GB RAM, new hosting model minimum is 4 GB RAM.
  disk_mb             = 5120 # Must be an increment of 512 megabytes. The minimum size of a read-only replica is 5 GB of disk
  depends_on          = [time_sleep.wait_time]
}

##############################################################################
# Outputs
##############################################################################
##############################################################################
# Outputs
##############################################################################
output "id" {
  description = "Postgresql instance id"
  value       = module.database.id
}

output "postgresql_crn" {
  description = "Postgresql CRN"
  value       = module.database.crn
}

output "version" {
  description = "Postgresql instance version"
  value       = module.database.version
}

output "adminuser" {
  description = "Database admin user name"
  value       = module.database.adminuser
}

output "hostname" {
  description = "Database connection hostname"
  value       = module.database.hostname
}

output "port" {
  description = "Database connection port"
  value       = module.database.port
}

output "certificate_base64" {
  description = "Database connection certificate"
  value       = module.database.certificate_base64
  sensitive   = true
}

output "read_replica_ids" {
  description = "Read-only replica Postgresql instance IDs"
  value       = module.read_only_replica_postgresql_db[*].id
}

output "read_replica_crns" {
  description = "Read-only replica Postgresql CRNs"
  value       = module.read_only_replica_postgresql_db[*].crn
}