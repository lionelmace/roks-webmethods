########################################################################################################################
# Provider config
########################################################################################################################

provider "ibm" {
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.region
}

provider "kubernetes" {
  host                   = data.ibm_container_cluster_config.cluster_config.host
  token                  = data.ibm_container_cluster_config.cluster_config.token
  cluster_ca_certificate = data.ibm_container_cluster_config.cluster_config.ca_certificate
}

provider "helm" {
  kubernetes = {
    host                   = data.ibm_container_cluster_config.cluster_config.host
    token                  = data.ibm_container_cluster_config.cluster_config.token
    cluster_ca_certificate = data.ibm_container_cluster_config.cluster_config.ca_certificate
  }
  # IBM Cloud credentials are required to authenticate to the helm repo
  registries = [{
    url      = "oci://icr.io/ibm/observe/logs-agent-helm"
    username = "iamapikey"
    password = var.ibmcloud_api_key
  }]
}


########################################################################################################################
# Container Registry
########################################################################################################################

provider "ibm" {
  alias            = "namespace"
  ibmcloud_api_key = var.ibmcloud_api_key
  region           = var.namespace_region
}

# Data source to retrieve token details
data "ibm_iam_auth_token" "token_data" {
}

# Data source to account settings
data "ibm_iam_account_settings" "iam_account_settings" {
}

provider "restapi" {
  uri                   = "https:"
  write_returns_object  = false
  create_returns_object = false
  debug                 = false # set to true to show detailed logs, but use carefully as it might print sensitive values.
  headers = {
    Account       = data.ibm_iam_account_settings.iam_account_settings.account_id
    Authorization = data.ibm_iam_auth_token.token_data.iam_access_token
    Content-Type  = "application/json"
  }
}