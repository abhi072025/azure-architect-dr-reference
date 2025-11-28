#  SQL  Failover  Group  runbook

##  Preconditions
-  App uses  Failover  Group  DNS  for SQL  connections.

##  Steps
1.  List  failover  groups:
     ```bash
     az  sql  failover-group  list --server  <primary-sql-server>  --resource-group  <rg>
     ```
2.  Force failover  to  secondary:
     ```bash
     az  sql  failover-group  set-primary  --name <fog-name>  --resource-group  <rg>  --server  <secondary-sql-server>
     ```
3. Validate  app  writes.
4.  Revert when  primary  is  healthy:
     ```bash
     az  sql  failover-group  set-primary --name  <fog-name>  --resource-group  <rg>  --server <primary-sql-server>
      ```
