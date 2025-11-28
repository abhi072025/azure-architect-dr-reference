 
 ---
 
 ## docs/architecture-dr.md
 
 ```markdown
 #  DR Architecture
 
 -  Paired  regions: West  Europe  (primary),  North  Europe (secondary).
 -  Compute:  AKS  in both  regions;  identical  manifests  and images.
 -  Ingress:  Application  Gateway WAF  per  region;  Azure  Front Door  for  global  failover.
 - Data:  Azure  SQL  Failover  Group (automatic  failover),  Cosmos  DB  multi-region with  automatic  failover.
 -  Identity: Managed  identities  for  AKS;  Key Vault  recommended;  Kubernetes  secrets  for bootstrap  in  demo.
 -  Observability: Log  Analytics  per  region;  health probes  via  /healthz.
