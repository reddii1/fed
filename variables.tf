# Generic Variables
variable "region" {
  description = "The region where the resource will be created. The full list of Azure regions can be found at https://azure.microsoft.com/regions"
  default     = "UK South"
}

variable "location" {
  description = "The location used in resource naming conventions"
  default     = "UK South"
}

variable "directorate" {
  description = "2 letter directory code"
  default     = "dd"
}

variable "business_unit" {
  description = "3 letter code for the business_unit"
  default     = "FED"
}

variable "environment" {
}

variable "resource_group_name" {
}

variable "resource_group_keyvault_name" {
}

variable "recovery_vault_name" {
}

variable "resource_group_keyvault_data_name" {
}

variable "adf_name" {
}

variable "sqlservername" {
}

variable "key_details" {
}

variable "sqldbname" {
}

variable "sqlpassword" {
}

# variable "storage_account_name" {
# }

variable "virtual_machine_name" {
}

#  variable "virtual_machine_name3" {
#  }

#  variable "virtual_machine_name2" {
#  }

variable "virtual_machine_name4" {
}

variable "virtual_machine_name5" {
}

variable "dwpdcip1" {
}

variable "dwpdcip2" {
}
variable "vmpassword" {
}

variable "virtual_network_name" {
}

variable "virtual_network_resourcegroup" {
}

variable "azurerm_resource_group" {
}

variable "azurerm_recovery_services_vault" {
}


# Asset Tag Variables
variable "tag_environment" {
  description = "The environment where the resource exists"
}

variable "tag_application" {
  description = "The resource belongs to this Technical Service (TechNow)"
}

variable "tag_function" {
  description = "The application belongs to this Function (TechNow)"
}

variable "tag_business_project" {
  description = "The cost code for the DDS project"
}

variable "tag_Persistence" {
  description = ""
}

variable "tag_service_owner" {
  description = "The service owner who is responsible for the DDS project"
}

variable "public_network_access_enabled" {
  description = "Whether public network access is allowed or not for this server"
  default     = ""
}

variable "managed_virtual_network_enabled" {
  description = "check managed virtual network"
  default     = ""
}

variable "adf_role_assignment" {
  type        = string
  description = "Role Assignment Name to share the ADFs"
}

variable "target_adf_principal_id" {
  type        = string
  description = "Principal ID of the target Data Factory to allow for SHIR sharing"
}

variable "target_adf_id" {
  type        = string
  description = "Resource ID of the target Data Factory SHIR"
}
