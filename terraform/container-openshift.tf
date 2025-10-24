


########################################################################################################################
# 3 zone OCP VPC cluster
########################################################################################################################

locals {
  # list of subnets in all zones
  subnets = [
    for subnet in ibm_is_subnet.subnets :
    {
      id         = subnet.id
      zone       = subnet.zone
      cidr_block = subnet.ipv4_cidr_block
    }
  ]

  # mapping of cluster worker pool names to subnets
  cluster_vpc_subnets = {
    zone-1 = local.subnets,
    zone-2 = local.subnets,
    zone-3 = local.subnets
  }

  boot_volume_encryption_kms_config = {
    crk             = module.kp_all_inclusive.keys["${local.key_ring}.${local.boot_volume_key}"].key_id
    kms_instance_id = module.kp_all_inclusive.kms_guid
  }

  worker_pools = [
    {
      subnet_prefix                     = "zone-1"
      pool_name                         = "default" # ibm_container_vpc_cluster automatically names default pool "default" (See https://github.com/IBM-Cloud/terraform-provider-ibm/issues/2849)
      machine_type                      = "bx2.16x64"
      workers_per_zone                  = 1
      operating_system                  = "RHCOS"
      enableAutoscaling                 = true
      minSize                           = 1
      maxSize                           = 6
      boot_volume_encryption_kms_config = local.boot_volume_encryption_kms_config
    },
    # {
    #   subnet_prefix                     = "zone-2"
    #   pool_name                         = "zone-2"
    #   machine_type                      = "bx2.16x64"
    #   workers_per_zone                  = 1
    #   secondary_storage                 = "300gb.5iops-tier"
    #   operating_system                  = "RHCOS"
    #   boot_volume_encryption_kms_config = local.boot_volume_encryption_kms_config
    # },
    # {
    #   subnet_prefix                     = "zone-3"
    #   pool_name                         = "zone-3"
    #   machine_type                      = "bx2.16x64"
    #   workers_per_zone                  = 1
    #   operating_system                  = "RHCOS"
    #   boot_volume_encryption_kms_config = local.boot_volume_encryption_kms_config
    # }
  ]

  worker_pools_taints = {
    all     = []
    default = []
    zone-2 = [{
      key    = "dedicated"
      value  = "zone-2"
      effect = "NoExecute"
    }]
    zone-3 = [{
      key    = "dedicated"
      value  = "zone-3"
      effect = "NoExecute"
    }]
  }
}

module "ocp_base" {
  source = "terraform-ibm-modules/base-ocp-vpc/ibm"

  cluster_name                     = var.prefix
  resource_group_id                = module.resource_group.resource_group_id
  region                           = var.region
  force_delete_storage             = true
  vpc_id                           = ibm_is_vpc.vpc.id
  vpc_subnets                      = local.cluster_vpc_subnets
  worker_pools                     = local.worker_pools
  ocp_version                      = var.ocp_version
  tags                             = var.resource_tags
  access_tags                      = var.access_tags
  worker_pools_taints              = local.worker_pools_taints
  ocp_entitlement                  = var.ocp_entitlement
  enable_openshift_version_upgrade = var.enable_openshift_version_upgrade
  # Enable if using worker autoscaling. Stops Terraform managing worker count.
  ignore_worker_pool_size_changes = true
  addons = {
    "cluster-autoscaler" = { version = "1.2.3" }
    "vpc-file-csi-driver" = { version = "2.0.16_443" }
  }
  kms_config = {
    instance_id = module.kp_all_inclusive.kms_guid
    crk_id      = module.kp_all_inclusive.keys["${local.key_ring}.${local.cluster_key}"].key_id
  }
}

data "ibm_container_cluster_config" "cluster_config" {
  cluster_name_id   = module.ocp_base.cluster_id
  resource_group_id = module.ocp_base.resource_group_id
  config_dir        = "${path.module}/../../kubeconfig"
}

########################################################################################################################
# Kube Audit
########################################################################################################################

module "kube_audit" {
  depends_on                = [module.ocp_base] # Wait for the cluster to completely deploy.
  source                    = "terraform-ibm-modules/base-ocp-vpc/ibm//modules/kube-audit"
  cluster_id                = module.ocp_base.cluster_id
  cluster_resource_group_id = module.resource_group.resource_group_id
  audit_log_policy          = "WriteRequestBodies"
  region                    = var.region
  ibmcloud_api_key          = var.ibmcloud_api_key
}
