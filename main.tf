terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.91.0"
    }
  }
}


provider "azurerm" {
  features {}
}


data "archive_file" "test" {
  type        = "zip"
  source_dir  = "./BlobTrigger"
  output_path = var.output_path
}


resource "azurerm_resource_group" "resource_group" {
  name     = "${var.project}rg"
  location = "East US"
}


resource "azurerm_storage_account" "storage_account" {
  name                     = "${var.project}st"
  resource_group_name      = azurerm_resource_group.resource_group.name
  location                 = azurerm_resource_group.resource_group.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_blob_public_access = true
}


resource "azurerm_storage_container" "storage_container" {
  name                  = "${var.project}stcont"
  storage_account_name  = azurerm_storage_account.storage_account.name
  container_access_type = "container"
}


resource "azurerm_storage_container" "input_storage_container" {
  name                  = "inputblob"
  storage_account_name  = azurerm_storage_account.storage_account.name
  container_access_type = "container"
}


resource "azurerm_storage_container" "output_storage_container" {
  name                  = "outputblob"
  storage_account_name  = azurerm_storage_account.storage_account.name
  container_access_type = "container"
}


resource "azurerm_storage_blob" "storage_blob" {
  name                   = filesha256(var.output_path)
  storage_account_name   = azurerm_storage_account.storage_account.name
  storage_container_name = azurerm_storage_container.storage_container.name
  type                   = "Block"
  source                 = var.output_path
}


data "azurerm_storage_account_blob_container_sas" "storage_account_blob_container_sas" {
  connection_string = azurerm_storage_account.storage_account.primary_connection_string
  container_name    = azurerm_storage_container.storage_container.name
  https_only        = true

  start  = "2022-01-01T00:00:00Z"
  expiry = "2022-12-31T00:00:00Z"

  permissions {
    read   = true
    add    = false
    create = false
    write  = false
    delete = false
    list   = false
  }
}


resource "azurerm_application_insights" "app_insights" {
  name                = "${var.project}app-insights"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  application_type    = "web"
}


resource "azurerm_app_service_plan" "app_service_plan" {
  name                = "${var.project}-app-service-plan"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  kind                = "FunctionApp"
  reserved            = true # This has to be set to true for Linux. Not related to the Premium Plan
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}


resource "azurerm_function_app" "function_app" {
  name                = "${var.project}-function-app"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location
  app_service_plan_id = azurerm_app_service_plan.app_service_plan.id
  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE"       = "https://${azurerm_storage_account.storage_account.name}.blob.core.windows.net/${azurerm_storage_container.storage_container.name}/${azurerm_storage_blob.storage_blob.name}${data.azurerm_storage_account_blob_container_sas.storage_account_blob_container_sas.sas}",
    "FUNCTIONS_WORKER_RUNTIME"       = "python",
    "AzureWebJobsDisableHomepage"    = "false",
    "https_only"                     = "false",
    "APPINSIGHTS_INSTRUMENTATIONKEY" = "${azurerm_application_insights.app_insights.instrumentation_key}"
  }
  os_type = "linux"
  site_config {
    linux_fx_version          = "Python|3.9"
    use_32_bit_worker_process = false
  }
  storage_account_name       = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key
  version                    = "~3"
}

