# Terraform Providers
provider "azurerm" {
  version = "2.87.0"
  features {}
}

# Terraform version, state backend and provider version
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-uks-sbox-fedmi-tfstate"
    storage_account_name = "miffedsboxukssttfstate"
    container_name       = "tfstate"
    key                  = "fedmi.terraform.tfstate"
  }
  required_providers {
    template = {
      source  = "hashicorp/template"
      version = "2.2.0"
    }
  }
}
