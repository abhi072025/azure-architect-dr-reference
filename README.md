# Azure  DR  Architect  Reference

Paired-region  disaster  recovery  architecture:  dual AKS  clusters  (West  Europe,  North Europe),  Application  Gateway  in  each, Azure  SQL  Failover  Group,  Cosmos DB  multi-region  with  automatic  failover, and  Azure  Front  Door  for global  traffic  failover.  CI/CD  deploys to  both  regions.

## Prerequisites
-  Azure  CLI,  Terraform >=  1.6,  Docker,  kubectl.
- Subscription  with  providers  registered:  ContainerService, Compute,  Network,  KeyVault,  Microsoft.DocumentDB,  FrontDoor.
-  ACR  login  permissions.

##  Deploy  infrastructure
```bash
az login
az  account  set  --subscription "<SUBSCRIPTION_ID>"
cd  infra/terraform
terraform  init
terraform  apply  -auto-approve  -var  'prefix=archdr' -var  'location=westeurope'  -var  'secondary_location=northeurope'
