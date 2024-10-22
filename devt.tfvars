# Generic Variables
region                          = "UK South"
location                        = "UK South"
directorate                     = "dd"
business_unit                   = "fedmi"
environment                     = "devt"
public_network_access_enabled   = false
managed_virtual_network_enabled = true
virtual_network_name            = "vnet-uks-devt-dd-mif"
virtual_network_resourcegroup   = "rg-uks-devt-dd-mif-network"


# Azure Tagging Strategy Variable Values: https://engineering.dwp.gov.uk/policies/hcs-cloud-hosting-policies/resource-identification-tagging/
tag_environment      = "DEVT"
tag_application      = "FED"
tag_function         = "Fraud Error & Debt"
tag_business_project = "PRJ0046283"
tag_service_owner    = "adele.kaute@dwp.gov.uk"

# Resource Group common name
resource_group_name = "rg-uks-devt1-mif-fedmi"

# Resource Group common name for keyvault
resource_group_keyvault_name = "rg-uks-devt-dd-mif-fedmi"

#recovery Vault comman name
recovery_vault_name = "fedmivaultbck"

#Gold image location
source_image_id = "/subscriptions/67e5f2ee-6e0a-49e3-b533-97f0beec351c/resourceGroups/rg-dwp-dev-ss-shared-images/providers/Microsoft.Compute/galleries/GoldImagesDevGallery/images/WIN2019-CIS2/versions/3.051.21819"

#Azure Data Factory name
adf_name                = "dwpdevtuksadfmiffedmi"
adf_role_assignment     = "Contributor"
target_adf_principal_id = "2b71567e-3a64-44be-8d9e-ecab3395ef69"
target_adf_id           = "/subscriptions/9e890891-857e-4f23-8030-ac1af80bd2ed/resourceGroups/rg-uks-devt-dd-crs-adf/providers/Microsoft.DataFactory/factories/adf-uks-devt-dd-crs/integrationruntimes/shir-uks-devt-dd-dds"

#Azure SQL Server name
sqlservername = "dwpdevtukssqlmiffedmi"

#Azure SQL DB name
sqldbname     = "dwpdevtuksdbmiffedmi"
sqldbdm12name = "dwpdevtuksdb12miffedmi"

#Azure Storage Account name for Datalake storage 
storage_account_name = "struksdevtddmiffedmidl"

#VM machine name
virtual_machine_name = "vmuksdevtddmif"

#VM machine name glod image
virtual_machine_name4 = "vmuksdevtddmif4"

#VM machine name glod image
virtual_machine_name5 = "vmuksdevtddmif5"

#DNS valuew
dwpdcip1 = "10.86.33.132"
dwpdcip2 = "10.86.33.133"

