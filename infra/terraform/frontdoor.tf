 resource  "azurerm_frontdoor"  "fd"  {
    name                             =  "${var.prefix}-fd"
    resource_group_name  =  azurerm_resource_group.rg.name
    routing_rule  {
        name                           =  "http-route"
        accepted_protocols =  ["Http"]
        patterns_to_match    =  ["/*"]
        frontend_endpoints =  [azurerm_frontdoor_frontend_endpoint.fd_fe.name]
        forwarding_configuration  {
            forwarding_protocol =  "MatchRequest"
            backend_pool_name     =  azurerm_frontdoor_backend_pool.fd_pool.name
        }
    }
 }
 
 resource  "azurerm_frontdoor_backend_pool" "fd_pool"  {
     name                            =  "archdr-pool"
     resource_group_name =  azurerm_resource_group.rg.name
     backends {
        host_header  =  azurerm_public_ip.agw_pip.ip_address
        address         =  azurerm_public_ip.agw_pip.ip_address
        http_port     =  80
        https_port    = 443
        priority        = 1
        weight           =  50
    }
     backends  {
        host_header =  azurerm_public_ip.agw_dr_pip.ip_address
        address         =  azurerm_public_ip.agw_dr_pip.ip_address
        http_port     =  80
        https_port    =  443
        priority       =  2
        weight          =  50
     }
    load_balancing  {  name =  "lb"  }
    health_probe      {  name =  "probe",  path  =  "/healthz", protocol  =  "Http",  interval_in_seconds  = 30  }
 }
 
 resource "azurerm_frontdoor_frontend_endpoint"  "fd_fe"  {
    name                             =  "archdr-fe"
    resource_group_name  =  azurerm_resource_group.rg.name
    frontdoor_name           =  azurerm_frontdoor.fd.name
    host_name                    =  "${var.prefix}-fd.azurefd.net"
 }
