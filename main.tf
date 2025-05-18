resource "azurerm_resource_group" "rg" {
  name = "deen-newre-rg"
  location = "West Us"
}

resource "azurerm_container_group" "aci" {
    name = "deen-newre-aci"
    location = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    os_type = "Windows"
 
    container {
      image = "mcr.microsoft.com/windows/servercore:10.0.17763.1158-amd64"
      memory = 2
      cpu = 1
      name = "deen-nr-aci"
 
      commands = ["ping", "-t", "localhost"]
 
      ports {
        port = 443
        protocol = "TCP"
      }
    }
  
}


resource "azurerm_eventhub_namespace" "evhns" {
    name = "newre-deen-evns"
    resource_group_name = azurerm_resource_group.rg.name
    location = azurerm_resource_group.rg.location
    sku = "Standard"
  
}

resource "azurerm_eventhub_namespace_authorization_rule" "diag" {
  name = "diag-settings"
  namespace_name = azurerm_eventhub_namespace.evhns.name
  resource_group_name = azurerm_resource_group.rg.name

  send = true
  listen = true
  manage = true
}

resource "azurerm_eventhub_namespace_authorization_rule" "cons" {
  name = "cons-settings"
  namespace_name = azurerm_eventhub_namespace.evhns.name
  resource_group_name = azurerm_resource_group.rg.name

  send = true
  listen = true
  manage = true
}

resource "azurerm_eventhub" "ev" {
  name = "deen-nr-evh"
  namespace_name = azurerm_eventhub_namespace.evhns.name
  resource_group_name = azurerm_resource_group.rg.name

  message_retention = 1
  partition_count = 2

}

resource "azurerm_monitor_diagnostic_setting" "name" {
    name = "aci-setting"
    target_resource_id = azurerm_container_group.aci.id

    eventhub_authorization_rule_id = azurerm_eventhub_namespace_authorization_rule.diag.id
    eventhub_name = azurerm_eventhub.ev.name

    enabled_log {
    category = "ContainerInstanceLog"
  }
  
}

resource "azurerm_eventhub_consumer_group" "consumer" {
  name = "func-cons"
  namespace_name = azurerm_eventhub_namespace.evhns.name
  resource_group_name = azurerm_resource_group.rg.name
  eventhub_name = azurerm_eventhub.ev.name
}

resource "azurerm_storage_account" "storage" {
  name                     = "deenstore5056067"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create the App service plan
resource "azurerm_service_plan" "svc" {
  name                = "deen-nr-svcplan"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  os_type             = "Windows"
  sku_name            = "Y1"
}

resource "azurerm_windows_function_app" "example" {
  name                = "nrlogsjjh"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  storage_account_name       = azurerm_storage_account.storage.name
  storage_account_access_key = azurerm_storage_account.storage.primary_access_key
  service_plan_id            = azurerm_service_plan.svc.id

  app_settings = {     
    "EVENTHUB_NAME"                = azurerm_eventhub.ev.name
    "EVENTHUB_CONSUMER_CONNECTION" = azurerm_eventhub_namespace_authorization_rule.cons.primary_connection_string
    "EVENTHUB_CONSUMER_GROUP"      = azurerm_eventhub_consumer_group.consumer.name
    "NR_LICENSE_KEY"               = "var.relic_secret_key"
    "NR_ENDPOINT"                  = "https://log-api.newrelic.com/log/v1"
    "NR_TAGS"                      = ""
    "NR_MAX_RETRIES"               = 3
    "NR_RETRY_INTERVAL"            = 2000
    "FUNCTIONS_EXTENSION_VERSION"  = "~4"
    "FUNCTIONS_WORKER_RUNTIME"     = "node"
    "WEBSITE_NODE_DEFAULT_VERSION" = "~20"
    "AzureWebJobsStorage"          = azurerm_storage_account.storage.primary_connection_string
    "WEBSITE_RUN_FROM_PACKAGE"     = "https://github.com/newrelic/newrelic-azure-functions/releases/latest/download/EventHubForwarder.zip"
  }

  site_config {

  }
}


