
##############################################################################
# Variables
##############################################################################

variable "namespace_region" {
  type        = string
  description = "The IBM Cloud region where the container registry namespace and retention policy will be created or where the existing namespace is located."
  default     = "eu-de"
}

variable "existing_namespace_name" {
  type        = string
  description = "The name of an existing namespace. Required if `namespace_name` is not provided."
  default     = null
}

variable "images_per_repo" {
  type        = number
  description = "Determines how many images will be retained for each repository when the retention policy is executed."
  default     = 2
}

variable "retain_untagged" {
  type        = bool
  description = "Determines if untagged images are retained when executing the retention policy."
  default     = false
}

##############################################################################
# Module
##############################################################################

module "namespace" {
  providers = {
    ibm = ibm.namespace
  }
  source                  = "../.."
  namespace_name          = var.prefix == null ? "namespace" : "${var.prefix}-namespace"
  existing_namespace_name = var.existing_namespace_name
  resource_group_id       = module.resource_group.resource_group_id
  tags                    = var.resource_tags
  images_per_repo         = var.images_per_repo
  retain_untagged         = var.retain_untagged
}

module "upgrade_plan" {
  source = "../..//modules/plan"
}

module "set_quota" {
  source            = "../../modules/quotas"
  storage_megabytes = 5 * 1024 - 1
  traffic_megabytes = 499
}

##############################################################################
# Outputs
##############################################################################

output "namespace_crn" {
  description = "CRN representing the namespace"
  value       = module.namespace.namespace_crn
}