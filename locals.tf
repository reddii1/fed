locals {
  virtual_network_name          = var.virtual_network_name
  virtual_network_resourcegroup = var.virtual_network_resourcegroup

  common_tags = {
    "Environment"      = var.tag_environment
    "Application"      = var.tag_application
    "Function"         = var.tag_function
    "Business-Project" = var.tag_business_project
    "Service Owner"    = var.tag_service_owner
  }

  dwp_ip_ranges = ["165.225.0.0/16", "185.235.98.0/24", "185.235.99.0/24", "167.98.150.128/28", "81.134.255.168/29", "52.56.34.58", "147.161.0.0/16"]

  target_adf = compact(split("/", var.target_adf_id))
}
