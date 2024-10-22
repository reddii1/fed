# Azure Account Information
data "azurerm_subscription" "primary" {
}

data "azurerm_client_config" "client_config" {
}

data "azurerm_subnet" "back-end-01" {
  name                 = "back-end-01"
  virtual_network_name = local.virtual_network_name
  resource_group_name  = local.virtual_network_resourcegroup
}

data "azurerm_subnet" "front-end-02" {
  name                 = "front-end-02"
  virtual_network_name = local.virtual_network_name
  resource_group_name  = local.virtual_network_resourcegroup
}

# FED-MI Resource Group to host ADF,SQL Server and Data Lake
resource "azurerm_resource_group" "rg_uks_fedmi_mif" {
  name     = var.resource_group_name
  location = var.region
  tags     = merge(local.common_tags, { "Name" = "FED-MI ADF Resource Group" })
}

# FED-MI Resource Group keyvault
resource "azurerm_resource_group" "rg_uks_fedmi_dd_mif" {
  name     = var.resource_group_keyvault_name
  location = var.region
  tags     = merge(local.common_tags, { "Name" = "FED-MI KEYVAULT Resource Group" })
}

# FED MI Azure data factory for etl
resource "azurerm_data_factory" "fedmi_adf" {
  name                            = var.adf_name
  location                        = azurerm_resource_group.rg_uks_fedmi_mif.location
  resource_group_name             = azurerm_resource_group.rg_uks_fedmi_mif.name
  tags                            = merge(local.common_tags, { "Name" = "FED-MI ADF" })
  managed_virtual_network_enabled = var.managed_virtual_network_enabled
  identity {
    type = "SystemAssigned"
  }
  # vsts_configuration {
  #   account_name    = "dwpgovuk"
  #   branch_name     = "main"
  #   project_name    = "dd-mif"
  #   repository_name = "dd-mif-adf"
  #   root_folder     = "/"
  #   tenant_id       = data.azurerm_client_config.client_config.tenant_id
  # }
}

resource "azurerm_role_assignment" "fedmi_crs_adf" {
  scope                = azurerm_data_factory.fedmi_adf.id
  role_definition_name = var.adf_role_assignment
  principal_id         = var.target_adf_principal_id
}

# resource "azurerm_data_factory_integration_runtime_self_hosted" "fedmi_crs_shir" {
#   name = var.adf_name

#   resource_group_name = local.target_adf[3]
#   data_factory_name   = local.target_adf[7]

#   rbac_authorization {
#     resource_id = var.target_adf_id
#   }

#   depends_on = [azurerm_role_assignment.fedmi_crs_adf]
# }

#FED MI Azure Sql Server
resource "azurerm_mssql_server" "sqlserver_fedmi" {
  name                          = var.sqlservername
  resource_group_name           = azurerm_resource_group.rg_uks_fedmi_mif.name
  location                      = azurerm_resource_group.rg_uks_fedmi_mif.location
  version                       = "12.0"
  administrator_login           = "dwpadministrator"
  administrator_login_password  = var.sqlpassword
  minimum_tls_version           = "1.2"
  tags                          = merge(local.common_tags, { "Name" = "FED-MI SQL Server" })
  public_network_access_enabled = var.public_network_access_enabled

  identity {
    type = "SystemAssigned"
  }

}

#FED MI Azure SQL Database
resource "azurerm_sql_database" "sqldb_fedmi" {
  name                = var.sqldbname
  resource_group_name = azurerm_resource_group.rg_uks_fedmi_mif.name
  location            = azurerm_resource_group.rg_uks_fedmi_mif.location
  server_name         = azurerm_mssql_server.sqlserver_fedmi.name
  tags                = merge(local.common_tags, { "Name" = "FED-MI SQL Database" })
}

resource "azurerm_mssql_server_transparent_data_encryption" "fedmicmkdb" {
  server_id        = azurerm_mssql_server.sqlserver_fedmi.id
  key_vault_key_id = azurerm_key_vault_key.cmkdb.id
  #key_vault_key_id = "https://kv-uks-devt-dd-mif-fedmi.vault.azure.net/keys/fedmi-cmkdb-temp/a5f895b89f9645109fcaa835dcfc1eb4"
}

#FEDMI Private endpoint SQl
resource "azurerm_private_endpoint" "fedmi-pe" {
  name                = "fedmipe_sql_pe"
  location            = azurerm_resource_group.rg_uks_fedmi_mif.location
  resource_group_name = azurerm_resource_group.rg_uks_fedmi_mif.name
  subnet_id           = data.azurerm_subnet.front-end-02.id
  tags                = merge(local.common_tags, { "Name" = "FED-MI ADF" })
  private_service_connection {
    name = "fedmipe_sql_ps"
    #private_connection_resource_id = "/subscriptions/35064730-8008-4bb0-bc58-50d53ec9a5af/resourceGroups/rg-uks-stag-mif-fedmi/providers/Microsoft.Sql/servers/dwpstagukssqlmiffedmi"
    private_connection_resource_id = azurerm_mssql_server.sqlserver_fedmi.id
    is_manual_connection           = false
    subresource_names              = ["sqlServer"]
  }
}

# #FED MI Azure DataLake Storage Account
# resource "azurerm_storage_account" "fedmist_datalake" {
#   name                     = var.storage_account_name
#   resource_group_name      = azurerm_resource_group.rg_uks_fedmi_mif.name
#   location                 = azurerm_resource_group.rg_uks_fedmi_mif.location
#   account_tier             = "Standard"
#   account_replication_type = "LRS"
#   account_kind             = "StorageV2"
#   is_hns_enabled           = "true"
#   tags                     = merge(local.common_tags, { "Name" = "FED-MI Datalake Storage" })
# }

# resource "azurerm_storage_container" "bronze" {
#   name                  = "bronze"
#   storage_account_name  = azurerm_storage_account.fedmist_datalake.name
#   container_access_type = "private"
# }

# resource "azurerm_storage_container" "silver" {
#   name                  = "silver"
#   storage_account_name  = azurerm_storage_account.fedmist_datalake.name
#   container_access_type = "private"
# }

# resource "azurerm_storage_container" "gold" {
#   name                  = "gold"
#   storage_account_name  = azurerm_storage_account.fedmist_datalake.name
#   container_access_type = "private"
# }

# resource "azurerm_storage_account_network_rules" "network_rules" {
#   storage_account_id = azurerm_storage_account.fedmist_datalake.id

#   default_action             = "Deny"
#   ip_rules                   = local.dwp_ip_ranges
#   virtual_network_subnet_ids = [data.azurerm_subnet.back-end-01.id]
#   bypass                     = ["Metrics"]
# }

# # VM Network Interface2
# resource "azurerm_network_interface" "uks_network_interface2" {
#   name                          = "nic-mif-fed2${var.virtual_machine_name}"
#   resource_group_name           = azurerm_resource_group.rg_uks_fedmi_mif.name
#   location                      = azurerm_resource_group.rg_uks_fedmi_mif.location
#   enable_ip_forwarding          = "false"
#   enable_accelerated_networking = "false"
#   tags                          = merge(local.common_tags, { "Name" = "FED-MI VM NIC" })

#   ip_configuration {
#     name                          = "ipconfig1"
#     subnet_id                     = data.azurerm_subnet.front-end-02.id
#     private_ip_address_allocation = "Dynamic"
#     primary                       = "true"
#   }
#   dns_servers = [
#       var.dwpdcip1,
#       var.dwpdcip2
#     ]
# }

# # VM Network Interface3
# resource "azurerm_network_interface" "uks_network_interface3" {
#   name                          = "nic-mif-fed3${var.virtual_machine_name}"
#   resource_group_name           = azurerm_resource_group.rg_uks_fedmi_mif.name
#   location                      = azurerm_resource_group.rg_uks_fedmi_mif.location
#   enable_ip_forwarding          = "false"
#   enable_accelerated_networking = "false"
#   tags                          = merge(local.common_tags, { "Name" = "FED-MI VM NIC" })

#   ip_configuration {
#     name                          = "ipconfig1"
#     subnet_id                     = data.azurerm_subnet.front-end-02.id
#     private_ip_address_allocation = "Dynamic"
#     primary                       = "true"
#   }
#   dns_servers = [
#       var.dwpdcip1,
#       var.dwpdcip2
#     ]
# }

# VM Network Interface4
resource "azurerm_network_interface" "uks_network_interface4" {
  name                          = "nic-mif-fed4${var.virtual_machine_name4}"
  resource_group_name           = azurerm_resource_group.rg_uks_fedmi_mif.name
  location                      = azurerm_resource_group.rg_uks_fedmi_mif.location
  enable_ip_forwarding          = "false"
  enable_accelerated_networking = "false"
  tags                          = merge(local.common_tags, { "Name" = "FED-MI VM NIC" })

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.front-end-02.id
    private_ip_address_allocation = "Dynamic"
    primary                       = "true"
  }
  dns_servers = [
    var.dwpdcip1,
    var.dwpdcip2
  ]
}

# VM Network Interface5
resource "azurerm_network_interface" "uks_network_interface5" {
  name                          = "nic-mif-fed5${var.virtual_machine_name5}"
  resource_group_name           = azurerm_resource_group.rg_uks_fedmi_mif.name
  location                      = azurerm_resource_group.rg_uks_fedmi_mif.location
  enable_ip_forwarding          = "false"
  enable_accelerated_networking = "false"
  tags                          = merge(local.common_tags, { "Name" = "FED-MI VM NIC" })

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.front-end-02.id
    private_ip_address_allocation = "Dynamic"
    primary                       = "true"
  }
  dns_servers = [
    var.dwpdcip1,
    var.dwpdcip2
  ]
}

# # Managemnet server creation 
# resource "azurerm_windows_virtual_machine" "virtual_machine_fedmi3" {
#   name                = var.virtual_machine_name3
#   resource_group_name = azurerm_resource_group.rg_uks_fedmi_mif.name
#   location            = azurerm_resource_group.rg_uks_fedmi_mif.location
#   size                = "Standard_D2s_v3"
#   admin_username      = "vmadminuser"
#   admin_password      = var.vmpassword
#   tags                = merge(local.common_tags, { "Name" = "FED-MI Virtual Machine" })
#   network_interface_ids = [
#     azurerm_network_interface.uks_network_interface3.id,
#   ]

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }

#  source_image_reference {
#     publisher = "MicrosoftWindowsServer"
#     offer     = "WindowsServer"
#     sku       = "2019-Datacenter"
#     version   = "latest"
#   }
# }
# #Join VM's in Domain
# resource "azurerm_virtual_machine_extension" "windows3" {
#   name                        = var.virtual_machine_name3
#   virtual_machine_id          = azurerm_windows_virtual_machine.virtual_machine_fedmi3.id
#   #location = azurerm_resource_group.rg_uks_fedmi_mif.location
#   #resource_group_name = azurerm_resource_group.rg_uks_fedmi_mif.name
#   #virtual_machine_name = var.virtual_machine_name
#   publisher = "Microsoft.Compute"
#   type = "JsonADDomainExtension"
#   type_handler_version = "1.3"
#   # What the settings mean: https://docs.microsoft.com/en-us/windows/desktop/api/lmjoin/nf-lmjoin-netjoindomain
#   settings = <<SETTINGS
#   {
#   "Name": "dwpdevcloud.local",
#   "OUPath": "OU=Management,OU=FedMI,OU=Windows 2019 Servers,OU=Management,DC=dwpdevcloud,DC=local",
#   "User": "dwpdevcloud\\svc_fedmi_adjoin",
#   "Restart": "true",
#   "Options": "3"
#   }
#   SETTINGS
#   protected_settings = <<PROTECTED_SETTINGS
#   {
#   "Password": "aJqs35fpjV8DRr"
#   }
#   PROTECTED_SETTINGS
#   #depends_on = ["azurerm_virtual_machine.vm"]
#   tags                = merge(local.common_tags, { "Name" = "FED-MI Virtual Machine" })
#   }

# Managemnet server creation GOld server image
resource "azurerm_windows_virtual_machine" "virtual_machine_fedmi4" {
  name                = var.virtual_machine_name4
  resource_group_name = azurerm_resource_group.rg_uks_fedmi_mif.name
  location            = azurerm_resource_group.rg_uks_fedmi_mif.location
  size                = "Standard_D2s_v3"
  admin_username      = "vmadminuser"
  admin_password      = var.vmpassword
  tags                = merge(local.common_tags, { "Name" = "FED-MI Virtual Machine" })
  network_interface_ids = [
    azurerm_network_interface.uks_network_interface4.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  #source_image_id = "/subscriptions/67e5f2ee-6e0a-49e3-b533-97f0beec351c/resourceGroups/rg-dwp-dev-ss-shared-images/providers/Microsoft.Compute/galleries/GoldImagesDevGallery/images/WIN2019-CIS2/versions/3.051.21819"
  source_image_id = "/subscriptions/7e97df51-9a8e-457a-ab7a-7502a771bb36/resourceGroups/rg-dwp-prd-ss-shared-images/providers/Microsoft.Compute/galleries/GoldImagesGallery/images/WIN2019-CIS2/versions/3.051.21819"

  provision_vm_agent         = true
  allow_extension_operations = true
}


resource "azurerm_virtual_machine_extension" "vmext" {
  name                 = "vmext"
  virtual_machine_id   = azurerm_windows_virtual_machine.virtual_machine_fedmi4.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  tags                 = merge(local.common_tags, { "Name" = "FED-MI Virtual Machine" })

  ### THIS PART IS ALL NEEDED, INCLUDING THE WEIRD SETTINGS BIT.  
  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(data.template_file.tf.rendered)}')) | Out-File -filepath diskinit.ps1\" && powershell -ExecutionPolicy Unrestricted -File diskinit.ps1"
        
    }
SETTINGS
}

data "template_file" "tf" {
  template = file("diskinit.ps1")
  #template = file("modules/compute/Windows_vm/diskinit.ps1/diskinit.ps1")
  #template = file("${path.module}/diskinit.ps1")
}


#Join VM's in Domain
resource "azurerm_virtual_machine_extension" "windows4" {
  name               = var.virtual_machine_name4
  virtual_machine_id = azurerm_windows_virtual_machine.virtual_machine_fedmi4.id
  #location = azurerm_resource_group.rg_uks_fedmi_mif.location
  #resource_group_name = azurerm_resource_group.rg_uks_fedmi_mif.name
  #virtual_machine_name = var.virtual_machine_name
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"
  depends_on           = [azurerm_virtual_machine_extension.vmext]
  # What the settings mean: https://docs.microsoft.com/en-us/windows/desktop/api/lmjoin/nf-lmjoin-netjoindomain
  settings           = <<SETTINGS
  {
  "Name": "dwpcloud.local",
  "OUPath": "OU=Management,OU=Production,OU=FEDMI,OU=Windows 2019 Servers,OU=Management,DC=dwpcloud,DC=local",
  "User": "dwpcloud\\svc_fedmi_adjoin",
  "Restart": "true",
  "Options": "3"
  }
  SETTINGS
  protected_settings = <<PROTECTED_SETTINGS
  {
  "Password": "C?1D5?hmVUOBbk"
  }
  PROTECTED_SETTINGS
  #depends_on = ["azurerm_virtual_machine.vm"]
  tags = merge(local.common_tags, { "Name" = "FED-MI Virtual Machine" })
}

# PoweBI GOld server image
resource "azurerm_windows_virtual_machine" "virtual_machine_fedmi5" {
  name                = var.virtual_machine_name5
  resource_group_name = azurerm_resource_group.rg_uks_fedmi_mif.name
  location            = azurerm_resource_group.rg_uks_fedmi_mif.location
  size                = "Standard_D2s_v3"
  admin_username      = "vmadminuser"
  admin_password      = var.vmpassword
  tags                = merge(local.common_tags, { "Name" = "FED-MI Virtual Machine" })
  network_interface_ids = [
    azurerm_network_interface.uks_network_interface5.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  #source_image_id = "/subscriptions/67e5f2ee-6e0a-49e3-b533-97f0beec351c/resourceGroups/rg-dwp-dev-ss-shared-images/providers/Microsoft.Compute/galleries/GoldImagesDevGallery/images/WIN2019-CIS2/versions/3.051.21819"
  source_image_id = "/subscriptions/7e97df51-9a8e-457a-ab7a-7502a771bb36/resourceGroups/rg-dwp-prd-ss-shared-images/providers/Microsoft.Compute/galleries/GoldImagesGallery/images/WIN2019-CIS2/versions/3.051.21819"

  provision_vm_agent         = true
  allow_extension_operations = true
}


resource "azurerm_virtual_machine_extension" "vmextb" {
  name                 = "vmextb"
  virtual_machine_id   = azurerm_windows_virtual_machine.virtual_machine_fedmi5.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"
  tags                 = merge(local.common_tags, { "Name" = "FED-MI Virtual Machine" })

  ### THIS PART IS ALL NEEDED, INCLUDING THE WEIRD SETTINGS BIT.  
  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -command \"[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('${base64encode(data.template_file.tf.rendered)}')) | Out-File -filepath diskinit.ps1\" && powershell -ExecutionPolicy Unrestricted -File diskinit.ps1"
        
    }
SETTINGS
}

data "template_file" "tf1" {
  template = file("diskinit.ps1")
  #template = file("modules/compute/Windows_vm/diskinit.ps1/diskinit.ps1")
  #template = file("${path.module}/diskinit.ps1")
}


#Join VM's in Domain
resource "azurerm_virtual_machine_extension" "windows5" {
  name               = var.virtual_machine_name5
  virtual_machine_id = azurerm_windows_virtual_machine.virtual_machine_fedmi5.id
  #location = azurerm_resource_group.rg_uks_fedmi_mif.location
  #resource_group_name = azurerm_resource_group.rg_uks_fedmi_mif.name
  #virtual_machine_name = var.virtual_machine_name
  publisher            = "Microsoft.Compute"
  type                 = "JsonADDomainExtension"
  type_handler_version = "1.3"
  depends_on           = [azurerm_virtual_machine_extension.vmextb]
  # What the settings mean: https://docs.microsoft.com/en-us/windows/desktop/api/lmjoin/nf-lmjoin-netjoindomain
  settings           = <<SETTINGS
  {
  "Name": "dwpcloud.local",
  "OUPath": "OU=PowerBI Gateway,OU=Production,OU=FEDMI,OU=Windows 2019 Servers,OU=Management,DC=dwpcloud,DC=local",
  "User": "dwpcloud\\svc_fedmi_adjoin",
  "Restart": "true",
  "Options": "3"
  }
  SETTINGS
  protected_settings = <<PROTECTED_SETTINGS
  {
  "Password": "C?1D5?hmVUOBbk"
  }
  PROTECTED_SETTINGS
  #depends_on = ["azurerm_virtual_machine.vm"]
  tags = merge(local.common_tags, { "Name" = "FED-MI Virtual Machine" })
}

# # PowerBI server creation 
# resource "azurerm_windows_virtual_machine" "virtual_machine_fedmi2" {
#   name                = var.virtual_machine_name2
#   resource_group_name = azurerm_resource_group.rg_uks_fedmi_mif.name
#   location            = azurerm_resource_group.rg_uks_fedmi_mif.location
#   size                = "Standard_D2s_v3"
#   admin_username      = "vmadminuser"
#   admin_password      = var.vmpassword
#   tags                = merge(local.common_tags, { "Name" = "FED-MI Virtual Machine" })
#   network_interface_ids = [
#     azurerm_network_interface.uks_network_interface2.id,
#   ]

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }

#   source_image_reference {
#     publisher = "MicrosoftWindowsServer"
#     offer     = "WindowsServer"
#     sku       = "2019-Datacenter"
#     version   = "latest"
#   }
# }

# #Join VM's in Domain
# resource "azurerm_virtual_machine_extension" "windows2" {
#   name                        = var.virtual_machine_name2
#   virtual_machine_id          = azurerm_windows_virtual_machine.virtual_machine_fedmi2.id
#   #location = azurerm_resource_group.rg_uks_fedmi_mif.location
#   #resource_group_name = azurerm_resource_group.rg_uks_fedmi_mif.name
#   #virtual_machine_name = var.virtual_machine_name
#   publisher = "Microsoft.Compute"
#   type = "JsonADDomainExtension"
#   type_handler_version = "1.3"
#   # What the settings mean: https://docs.microsoft.com/en-us/windows/desktop/api/lmjoin/nf-lmjoin-netjoindomain
#   settings = <<SETTINGS
#   {
#   "Name": "dwpdevcloud.local",
#   "OUPath": "OU=Management,OU=FedMI,OU=Windows 2019 Servers,OU=Management,DC=dwpdevcloud,DC=local",
#   "User": "dwpdevcloud\\svc_fedmi_adjoin",
#   "Restart": "true",
#   "Options": "3"
#   }
#   SETTINGS
#   protected_settings = <<PROTECTED_SETTINGS
#   {
#   "Password": "aJqs35fpjV8DRr"
#   }
#   PROTECTED_SETTINGS
#   #depends_on = ["azurerm_virtual_machine.vm"]
#   tags                = merge(local.common_tags, { "Name" = "FED-MI Virtual Machine" })
#   }

# resource "azurerm_log_analytics_workspace" "fedmivmdiagnosticsstg" {
#   name                = "dd-fedmi-workspace"
#   location            = azurerm_resource_group.rg_uks_fedmi_mif.location
#   resource_group_name = azurerm_resource_group.rg_uks_fedmi_mif.name
#   sku                 = "PerGB2018"
#   tags                = merge(local.common_tags, { "Name" = "FED-MI Virtual Machine" })
# }

# resource "azurerm_monitor_diagnostic_setting" "fedmivmdiagnosticsstg" {
#   name               = "fedmivmdiagnosticsstg"
#   target_resource_id = azurerm_windows_virtual_machine.virtual_machine_fedmi5.id


#   log_analytics_workspace_id = azurerm_log_analytics_workspace.fedmivmdiagnosticsstg.id

#   metric {
#     category = "AllMetrics"

#     retention_policy {
#       enabled = true
#       days    = 7
#     }
#   }
# }

# resource "azurerm_monitor_action_group" "main" {
#   name                = "metricAlerts"
#   resource_group_name = azurerm_resource_group.rg_uks_fedmi_mif.name
#   short_name          = "fedmitest"
#   tags                = merge(local.common_tags, { "Name" = "FED-MI Virtual Machine" })

# #   # webhook_receiver {
# #   #   name        = "callmyapi"
# #   #   service_uri = "http://example.com/alert"
# #   # }
# }

# data "azurerm_monitor_action_group" "bmc_action_group" {
#     provider            =   azurerm.bmc_actiongroup_sub
#     resource_group_name =   "rg-dwp-bmc-${var.BMC_env}-dw-ts-core"
#     name                =   "Azure BMC Integration"
# }

# resource "azurerm_monitor_metric_alert" "vmcpuwarning" {
#     #name                = "FED MI Platform "
#     name                = "FEDMIPlatform "
#     resource_group_name = azurerm_resource_group.rg_uks_fedmi_mif.name
#     scopes              = ["/subscriptions/7663e89d-7565-42d5-a9b4-b90aa45b71a7/resourceGroups/rg-uks-test-mif-fedmi/providers/Microsoft.Compute/virtualMachines/vmukstestddmifb"]
#     description         = "Warning Alert will be triggered when the CPU threshold exceeds maximum limit"
#     severity            = 4
#     tags                = merge(local.common_tags, { "Name" = "FED-MI Virtual Machine" })
#     #enabled             = var.enable
#     frequency           = "PT5M"
#     window_size         = "PT5M"
#     criteria {
#       #metric_namespace = "Microsoft.Compute/virtualMachineScaleSets"
#       metric_namespace = "Microsoft.Compute/virtualMachines"
#       metric_name      = "Percentage CPU"
#       operator         = "GreaterThan"
#       aggregation      = "Maximum"
#       threshold        = 80
#   }
#   action {
#     #action_group_id = "/subscriptions/7663e89d-7565-42d5-a9b4-b90aa45b71a7/resourceGroups/rg-uks-test-mif-fedmi/providers/microsoft.insights/components/fed-qat-test-dd-mif-app-insights"
#     #action_group_id = "/subscriptions/7663e89d-7565-42d5-a9b4-b90aa45b71a7/resourceGroups/rg-uks-test-mif-fedmi/providers/microsoft.insights/metricAlerts/fed-qat-test-dd-mif-app-insights-new"
#     action_group_id = azurerm_monitor_action_group.main.id
#   }
#   #tags = merge(local.common_tags)
# }


# log {
#   category = "PipelineRuns"
#   enabled  = true

#   retention_policy {
#     enabled = true
#     days    = 30
#   }
# }

# resource "azurerm_log_analytics_workspace" "vmdiagnostics1" {
#   name                = "fedmi-workspace"
#   location            = azurerm_resource_group.rg_uks_fedmi_mif.location
#   resource_group_name = azurerm_resource_group.rg_uks_fedmi_mif.name
#   sku                 = "PerGB2018"
# }

# resource "azurerm_monitor_diagnostic_setting" "vmdiagnostics1" {
#   name               = "vmdiagnostics1"
#   target_resource_id = azurerm_windows_virtual_machine.virtual_machine_fedmi3.id


#   log_analytics_workspace_id = azurerm_log_analytics_workspace.vmdiagnostics.id

#   metric {
#     category = "AllMetrics"

#     retention_policy {
#       enabled = true
#       days    = 7
#     }
#   }

#   # log {
#   #   category = "PipelineRuns"
#   #   enabled  = true

#   #   retention_policy {
#   #     enabled = true
#   #     days    = 30
#   #   }
#   # }
# }



# resource "azurerm_resource_group" "rg_uks_fedmi_mif_vmbck" {
#   name     = "fedmi-recovery_vault"
#   location = "var.region"
# }

resource "azurerm_recovery_services_vault" "fedmi_vault_bck" {
  name                = "fedmi"
  location            = azurerm_resource_group.rg_uks_fedmi_mif.location
  resource_group_name = azurerm_resource_group.rg_uks_fedmi_mif.name
  sku                 = "Standard"
  tags                = merge(local.common_tags, { "Name" = "FED-MI Virtual Machine" })
}

resource "azurerm_backup_policy_vm" "fedmi_vault_policy" {
  name                = "fedmi-recovery-vault-policy"
  resource_group_name = azurerm_resource_group.rg_uks_fedmi_mif.name
  recovery_vault_name = azurerm_recovery_services_vault.fedmi_vault_bck.name
  #tags                = merge(local.common_tags, { "Name" = "FED-MI Virtual Machine" })

  timezone = "UTC"

  backup {
    frequency = "Daily"
    time      = "00:00"
  }

  retention_daily {
    count = 7
  }

  retention_weekly {
    count    = 4
    weekdays = ["Sunday"]
  }
}

resource "azurerm_key_vault_secret" "DM11-DM-P9-KV" {
  name            = "DM11-DM-P8-KV"
  value           = "Iu(bFT0bOxhwn(96Pt(5"
  key_vault_id    = azurerm_key_vault.kv-uks-pr-dd-mif-fedmi.id
  expiration_date = "2024-12-31T00:00:00Z"

  depends_on = [
    azurerm_key_vault.kv-uks-pr-dd-mif-fedmi
  ]
}

resource "azurerm_key_vault_secret" "FEDMI-DM-P9-KV" {
  name            = "FEDMI-DM-P8-KV"
  value           = "Dwp@fed-mi1Mif!"
  key_vault_id    = azurerm_key_vault.kv-uks-pr-dd-mif-fedmi.id
  expiration_date = "2024-12-31T00:00:00Z"

  depends_on = [
    azurerm_key_vault.kv-uks-pr-dd-mif-fedmi
  ]
}

resource "azurerm_key_vault_key" "cmkdb" {
  name            = "fedmicmkdbfinal"
  key_vault_id    = var.resource_group_keyvault_data_name
  key_type        = "RSA"
  key_size        = 2048
  expiration_date = "2025-11-29T12:30:21Z"
  not_before_date = "2023-11-29T12:30:21Z"

  key_opts = [
    "decrypt",
    "encrypt",
    "sign",
    "unwrapKey",
    "verify",
    "wrapKey",
  ]

  # key_properties {
  #   key_type = "RSA"
  #   expires  = "2025-12-31T23:59:59Z" # Set the expiration date in UTC format
  # }

  # rotation_policy {
  #   automatic {
  #     time_before_expiry = "P30D"
  #   }

  #   expire_after         = "P90D"
  #   notify_before_expiry = "P29D"
  # }
}



#Azure Key Vault creation
resource "azurerm_key_vault" "kv-uks-pr-dd-mif-fedmi" {
  name     = "kv-uks-pr-dd-mif-fedmi"
  location = azurerm_resource_group.rg_uks_fedmi_mif.location
  #resource_group_name         = azurerm_resource_group.rg_uks_fedmi_mif.name
  resource_group_name         = azurerm_resource_group.rg_uks_fedmi_dd_mif.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.client_config.tenant_id
  soft_delete_enabled         = true
  soft_delete_retention_days  = 7
  purge_protection_enabled    = true
  tags                        = merge(local.common_tags, { "Name" = "FED-MI KV" })

  sku_name = "standard"
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    #bypass   = ["Metrics"]
    ip_rules                   = local.dwp_ip_ranges
    virtual_network_subnet_ids = [data.azurerm_subnet.front-end-02.id]
  }
  access_policy {
    tenant_id = data.azurerm_client_config.client_config.tenant_id
    object_id = data.azurerm_client_config.client_config.object_id

    key_permissions = [
      "Get",
      "List",
      "Update",
      "Create",
      "WrapKey",
      "UnwrapKey",
      "Delete",
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
    ]

    storage_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
    ]
  }

  #   access_policy {
  #   tenant_id = data.azurerm_client_config.client_config.tenant_id
  #   object_id = "793fcf68-a86b-481f-983d-a5b0d859169a"

  #   key_permissions = [
  #     "Get",
  #     "List",
  #     "Update",
  #     "Create",
  #     "WrapKey",
  #     "UnwrapKey",
  #     "Delete",
  #   ]

  #   secret_permissions = [
  #     "Get",
  #     "List",
  #     "Set",
  #     "Delete",
  #   ]

  #   storage_permissions = [
  #     "Get",
  #     "List",
  #     "Set",
  #     "Delete",
  #   ]
  # }
  access_policy {
    tenant_id = data.azurerm_client_config.client_config.tenant_id
    object_id = "fe618064-2472-4359-95b9-63b9e8e36125"

    key_permissions = [
      "Get",
      "List",
      "Create",
      "WrapKey",
      "UnwrapKey",
      "Delete",
    ]

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
    ]

    storage_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
    ]
  }


}

resource "azurerm_key_vault_access_policy" "kv-uks-pr-dd-mif-fedmi" {
  key_vault_id = azurerm_key_vault.kv-uks-pr-dd-mif-fedmi.id
  tenant_id    = data.azurerm_client_config.client_config.tenant_id
  object_id    = "c656be66-d301-457c-aff1-ec930e777995"

  key_permissions = [
    "Get",
    "List",
    "Update",
    "Create",
    "WrapKey",
    "UnwrapKey",
    "Delete",
  ]
  secret_permissions = [
    "get",
    "list",
    "Delete",
    "Set",
  ]

  storage_permissions = [
    "Get",
    "List",
    "Set",
    "Delete",
  ]
}

resource "azurerm_log_analytics_workspace" "dd-fed-prod-7-workspace" {
  name                = "dd-fed-prod-7-workspace"
  location            = azurerm_resource_group.rg_uks_fedmi_mif.location
  resource_group_name = azurerm_resource_group.rg_uks_fedmi_mif.name
  sku                 = "PerGB2018"
  tags                = merge(local.common_tags, { "Name" = "FED-MI Virtual Machine" })
}

resource "azurerm_monitor_diagnostic_setting" "fedmivmdiagnosticdd-dmi-prod-1-workspacesz" {
  name               = "fedmivmdiagnosticsq"
  target_resource_id = azurerm_windows_virtual_machine.virtual_machine_fedmi5.id


  log_analytics_workspace_id = azurerm_log_analytics_workspace.dd-fed-prod-7-workspace.id

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = true
      days    = 7
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "fedmivmdiagnosticdd-dmi-prod-1-workspacesj" {
  name               = "fedmivmdiagnosticsj"
  target_resource_id = azurerm_windows_virtual_machine.virtual_machine_fedmi4.id


  log_analytics_workspace_id = azurerm_log_analytics_workspace.dd-fed-prod-7-workspace.id

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = true
      days    = 7
    }
  }
}
