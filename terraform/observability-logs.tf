########################################################################################################################
# Observability (Instance + Agents)
########################################################################################################################

locals {
  logs_agent_namespace = "ibm-observe"
  logs_agent_name      = "logs-agent"
}

module "cloud_logs" {
  source            = "terraform-ibm-modules/cloud-logs/ibm"
  version           = "1.9.2"
  resource_group_id = module.resource_group.resource_group_id
  region            = var.region
  plan              = "standard"
  instance_name     = "${var.prefix}-cloud-logs"
}

module "trusted_profile" {
  source                      = "terraform-ibm-modules/trusted-profile/ibm"
  version                     = "3.1.1"
  trusted_profile_name        = "${var.prefix}-profile"
  trusted_profile_description = "Logs agent Trusted Profile"
  # As a `Sender`, you can send logs to your IBM Cloud Logs service instance - but not query or tail logs. This role is meant to be used by agents and routers sending logs.
  trusted_profile_policies = [{
    roles             = ["Sender"]
    unique_identifier = "${var.prefix}-profile-0"
    resources = [{
      service = "logs"
    }]
  }]
  # Set up fine-grained authorization for `logs-agent` running in ROKS cluster in `ibm-observe` namespace.
  trusted_profile_links = [{
    cr_type           = "ROKS_SA"
    unique_identifier = "${var.prefix}-profile"
    links = [{
      crn       = module.ocp_base.cluster_crn
      namespace = local.logs_agent_namespace
      name      = local.logs_agent_name
    }]
    }
  ]
}

module "logs_agents" {
  depends_on                    = [module.kube_audit]
  source                        = "terraform-ibm-modules/logs-agent/ibm"
  version                       = "1.9.2"
  cluster_id                    = module.ocp_base.cluster_id
  cluster_resource_group_id     = module.resource_group.resource_group_id
  logs_agent_trusted_profile_id = module.trusted_profile.trusted_profile.id
  logs_agent_namespace          = local.logs_agent_namespace
  logs_agent_name               = local.logs_agent_name
  cloud_logs_ingress_endpoint   = module.cloud_logs.ingress_private_endpoint
  cloud_logs_ingress_port       = 3443
  # example of how to add additional metadata to the logs agents
  logs_agent_additional_metadata = [{
    key   = "cluster_id"
    value = module.ocp_base.cluster_id
  }]
  # example of how to add only kube-audit log source path
  logs_agent_selected_log_source_paths = ["/var/log/audit/*.log"]
}