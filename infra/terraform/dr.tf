locals  {
   rg2_name                =  "${var.prefix}-rg-dr"
   vnet_spoke2_name  =  "${var.prefix}-spoke-vnet-dr"
   aks2_name               =  "${var.prefix}-aks-dr"
   acr2_name              =  replace("${var.prefix}acrdr",  "-",  "")
   agw2_name               = "${var.prefix}-agw-dr"
    sqlsrv2_name         =  "${var.prefix}-sqlsrv-dr"
}

resource  "azurerm_resource_group"  "rg_dr" {
    name         =  local.rg2_name
   location  =  var.secondary_location
   tags         =  {  env =  "prod-dr",  cost  =  "archdr" }
}

resource  "azurerm_container_registry" "acr_dr"  {
    name                            =  local.acr2_name
    resource_group_name =  azurerm_resource_group.rg_dr.name
    location                     =  var.secondary_location
   sku                               =  "Basic"
   admin_enabled             =  false
}

resource  "azurerm_virtual_network"  "spoke_dr" {
    name                             = local.vnet_spoke2_name
    location                     =  var.secondary_location
    resource_group_name =  azurerm_resource_group.rg_dr.name
    address_space            =  ["10.20.0.0/16"]
}

resource  "azurerm_subnet"  "aks_dr"  {
   name                               =  "aks-subnet"
   resource_group_name    = azurerm_resource_group.rg_dr.name
    virtual_network_name  = azurerm_virtual_network.spoke_dr.name
    address_prefixes         =  ["10.20.1.0/24"]
}

resource  "azurerm_subnet"  "agw_dr" {
    name                              =  "agw-subnet"
    resource_group_name   =  azurerm_resource_group.rg_dr.name
   virtual_network_name  =  azurerm_virtual_network.spoke_dr.name
   address_prefixes         =  ["10.20.2.0/24"]
}

resource "azurerm_public_ip"  "agw_dr_pip"  {
   name                             =  "${var.prefix}-agw-dr-pip"
   location                      =  var.secondary_location
   resource_group_name  =  azurerm_resource_group.rg_dr.name
   allocation_method      = "Static"
    sku                              =  "Standard"
}

resource "azurerm_application_gateway"  "agw_dr"  {
   name                             =  local.agw2_name
   location                      =  var.secondary_location
   resource_group_name  =  azurerm_resource_group.rg_dr.name
   sku  {  name  = "WAF_v2",  tier  =  "WAF_v2",  capacity =  2  }
   gateway_ip_configuration  {  name  =  "agw-ipcfg", subnet_id  =  azurerm_subnet.agw_dr.id  }
   frontend_port  {  name  = "http",  port  =  80  }
   frontend_ip_configuration  {  name =  "pip",  public_ip_address_id  =  azurerm_public_ip.agw_dr_pip.id }
    backend_address_pool  { name  =  "aks-pool"  }
   backend_http_settings  {  name  = "http-settings",  port  =  80,  protocol =  "Http",  request_timeout  =  30 }
    http_listener  { name  =  "http-listener",  frontend_ip_configuration_name  = "pip",  frontend_port_name  =  "http",  protocol =  "Http"  }
   request_routing_rule  {  name  =  "rule1", rule_type  =  "Basic",  http_listener_name  = "http-listener",  backend_address_pool_name  =  "aks-pool",  backend_http_settings_name =  "http-settings"  }
   waf_configuration  {  enabled  =  true, firewall_mode  =  "Prevention",  rule_set_version  = "3.2"  }
}

resource "azurerm_kubernetes_cluster"  "aks_dr"  {
   name                             =  local.aks2_name
   location                      =  var.secondary_location
   resource_group_name  =  azurerm_resource_group.rg_dr.name
   dns_prefix                  =  "${var.prefix}-aks-dr"
   kubernetes_version    =  azurerm_kubernetes_cluster.aks.kubernetes_version
   default_node_pool  {
       name                           =  "system"
       node_count                =  2
       vm_size                     =  "Standard_DS3_v2"
       vnet_subnet_id         =  azurerm_subnet.aks_dr.id
       type                           =  "VirtualMachineScaleSets"
       availability_zones  = [1,  2,  3]
   }
    identity  { type  =  "SystemAssigned"  }
   network_profile  {  network_plugin  = "azure",  load_balancer_sku  =  "standard"  }
}

resource  "azurerm_role_assignment"  "aks_dr_acr_pull" {
    scope                             = azurerm_container_registry.acr_dr.id
    role_definition_name  = "AcrPull"
    principal_id                =  azurerm_kubernetes_cluster.aks_dr.kubelet_identity[0].object_id
}

resource  "azurerm_mssql_server"  "sql_dr"  {
   name                                             =  local.sqlsrv2_name
   resource_group_name                  =  azurerm_resource_group.rg_dr.name
   location                                      =  var.secondary_location
   version                                        =  "12.0"
   administrator_login                  =  azurerm_mssql_server.sql.administrator_login
   administrator_login_password  =  azurerm_mssql_server.sql.administrator_login_password
   identity  {  type  =  "SystemAssigned" }
}

resource  "azurerm_mssql_database" "ordersdb_dr"  {
    name          =  azurerm_mssql_database.ordersdb.name
    server_id =  azurerm_mssql_server.sql_dr.id
    sku_name   =  azurerm_mssql_database.ordersdb.sku_name
}

resource  "azurerm_mssql_failover_group"  "fog"  {
   name                             =  "${var.prefix}-fog"
   resource_group_name  =  azurerm_resource_group.rg.name
   server_name                =  azurerm_mssql_server.sql.name
    databases                   =  [azurerm_mssql_database.ordersdb.id]
    partner_servers {  id  =  azurerm_mssql_server.sql_dr.id  }
   read_write_endpoint_failover_policy  {  mode =  "Automatic",  grace_minutes  =  60 }
    read_only_endpoint_failover_policy   {  mode  =  "Enabled"  }
   tags  =  { env  =  "prod",  dr  = "paired"  }
}

resource "azurerm_cosmosdb_account"  "cosmos_dr_update"  {
   name                                               =  azurerm_cosmosdb_account.cosmos.name
   location                                        =  var.location
   resource_group_name                    =  azurerm_resource_group.rg.name
   offer_type                                    =  "Standard"
   kind                                               =  "GlobalDocumentDB"
   capabilities                                 {  name =  "EnableServerless"  }
   geo_location                                 {  location =  var.location,                    failover_priority  =  0 }
    geo_location                                {  location  =  var.secondary_location, failover_priority  =  1  }
   enable_automatic_failover         =  true
   consistency_policy                      {  consistency_level  = "Session"  }
    lifecycle {
       ignore_changes  =  [capabilities,  consistency_policy]
   }
}
