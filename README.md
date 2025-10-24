# Terraform scripts to deploy webMethods

Those Terraform scripts will provision the following services
* VPC with 3 subnets to host the cluster
* Managed OpenShift cluster version 4.18
* Databases for Postgres
* Cloud Logs
* Cloud Object Storage to store the OpenShift Registry.

Those scripts leverage existing Terraform modules:
* [Red Hat OpenShift VPC cluster on IBM Cloud](https://github.com/terraform-ibm-modules/terraform-ibm-base-ocp-vpc)
* [IBM Cloud Databases for PostgreSQL service](https://github.com/terraform-ibm-modules/terraform-ibm-icd-postgresql)