locals  {
   rg_name                =  "${var.prefix}-rg"
   vnet_spoke_name  =  "${var.prefix}-spoke-vnet"
   aks_name               =  "${var.prefix}-aks"
   acr_name              =  replace("${var.prefix}acr",  "-",  "")
   agw_name               = "${var.prefix}-agw"
    kv_name                =  "${var.prefix}-kv"
}

resource  "azurerm_resource_group"  "rg"  {
   name         =  local.rg_name
   location  =  var.location
   tags         =  {  env  = "prod",  cost  =  "archdr"  }
}

resource  "azurerm_virtual_network"  "spoke" {
    name                             = local.vnet_spoke_name
    location                     =  var.location
    resource_group_name =  azurerm_resource_group.rg.name
    address_space            =  ["10.10.0.0/16"]
}

resource  "azurerm_subnet"  "aks"  {
   name                               =  "aks-subnet"
   resource_group_name    = azurerm_resource_group.rg.name
    virtual_network_name  = azurerm_virtual_network.spoke.name
    address_prefixes         =  ["10.10.1.0/24"]
}

resource  "azurerm_subnet"  "agw" {
    name                              =  "agw-subnet"
    resource_group_name   =  azurerm_resource_group.rg.name
   virtual_network_name  =  azurerm_virtual_network.spoke.name
   address_prefixes         =  ["10.10.2.0/24"]
}

resource "azurerm_container_registry"  "acr"  {
   name                             =  local.acr_name
   resource_group_name  =  azurerm_resource_group.rg.name
   location                      =  var.location
   sku                               =  "Basic"
   admin_enabled             = false
}

resource  "azurerm_log_analytics_workspace" "law"  {
    name                            =  "${var.prefix}-law"
    location                     =  var.location
   resource_group_name  =  azurerm_resource_group.rg.name
   sku                               =  "PerGB2018"
   retention_in_days      = 30
}

resource  "random_password" "sql_admin"  {
    length   =  20
   special  =  true
}

resource  "azurerm_mssql_server"  "sql"  {
   name                                             =  "${var.prefix}-sqlsrv"
   resource_group_name                  =  azurerm_resource_group.rg.name
    location                                     =  var.location
    version                                       =  "12.0"
   administrator_login                  =  "sqladminuser"
    administrator_login_password =  coalesce(var.sql_admin_password,  random_password.sql_admin.result)
   identity  {  type  =  "SystemAssigned" }
}

resource  "azurerm_mssql_database" "ordersdb"  {
    name                   =  "ordersdb"
    server_id          =  azurerm_mssql_server.sql.id
    sku_name            =  "GP_S_Gen5_2"
   zone_redundant  =  true
}

resource  "azurerm_cosmosdb_account"  "cosmos"  {
   name                             =  "${var.prefix}-cosmos"
   location                      =  var.location
   resource_group_name  =  azurerm_resource_group.rg.name
   offer_type                  =  "Standard"
   kind                             =  "GlobalDocumentDB"
   capabilities  {  name  = "EnableServerless"  }
    consistency_policy {  consistency_level  =  "Session"  }
   geo_location  {  location =  var.location,  failover_priority  =  0 }
}

resource  "azurerm_cosmosdb_sql_database" "catalogdb"  {
    name                            =  "catalogdb"
    resource_group_name =  azurerm_resource_group.rg.name
    account_name              =  azurerm_cosmosdb_account.cosmos.name
}

resource  "azurerm_cosmosdb_sql_container"  "products"  {
   name                                =  "products"
    resource_group_name     =  azurerm_resource_group.rg.name
   account_name                  =  azurerm_cosmosdb_account.cosmos.name
   database_name                 = azurerm_cosmosdb_sql_database.catalogdb.name
    partition_key_path       =  "/category"
   partition_key_version  =  2
}

resource  "azurerm_public_ip"  "agw_pip"  {
   name                             =  "${var.prefix}-agw-pip"
   location                      = var.location
    resource_group_name  = azurerm_resource_group.rg.name
    allocation_method     =  "Static"
   sku                               =  "Standard"
}

resource  "azurerm_application_gateway"  "agw"  {
   name                             =  local.agw_name
   location                      = var.location
    resource_group_name  = azurerm_resource_group.rg.name
    sku  { name  =  "WAF_v2",  tier  = "WAF_v2",  capacity  =  2  }
   gateway_ip_configuration  {  name =  "agw-ipcfg",  subnet_id  =  azurerm_subnet.agw.id }
    frontend_port  { name  =  "http",  port  = 80  }
    frontend_ip_configuration {  name  =  "pip",  public_ip_address_id =  azurerm_public_ip.agw_pip.id  }
   backend_address_pool  {  name  =  "aks-pool" }
    backend_http_settings  { name  =  "http-settings",  port  = 80,  protocol  =  "Http",  request_timeout =  30  }
   http_listener  {  name  =  "http-listener", frontend_ip_configuration_name  =  "pip",  frontend_port_name  = "http",  protocol  =  "Http"  }
   request_routing_rule  {  name =  "rule1",  rule_type  =  "Basic", http_listener_name  =  "http-listener",  backend_address_pool_name  = "aks-pool",  backend_http_settings_name  =  "http-settings"  }
   waf_configuration  {  enabled =  true,  firewall_mode  =  "Prevention", rule_set_version  =  "3.2"  }
}

resource  "azurerm_kubernetes_cluster"  "aks"  {
   name                             =  local.aks_name
   location                      = var.location
    resource_group_name  = azurerm_resource_group.rg.name
    dns_prefix                  =  "${var.prefix}-aks"
   kubernetes_version    = "1.29.7"
    default_node_pool  {
       name                           = "system"
       node_count                 = 2
       vm_size                      =  "Standard_DS3_v2"
       vnet_subnet_id         =  azurerm_subnet.aks.id
       type                           = "VirtualMachineScaleSets"
       availability_zones  =  [1,  2,  3]
       upgrade_settings {  max_surge  =  1  }
   }
   identity  {  type  =  "SystemAssigned" }
    network_profile  { network_plugin  =  "azure",  load_balancer_sku  = "standard"  }
    microsoft_defender {  log_analytics_workspace_id  =  azurerm_log_analytics_workspace.law.id  }
}

resource  "azurerm_role_assignment"  "aks_acr_pull" {
    scope                             = azurerm_container_registry.acr.id
    role_definition_name  = "AcrPull"
    principal_id                =  azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}
