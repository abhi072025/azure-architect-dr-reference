#  Traffic failover  runbook  (Front  Door)

##  Preconditions
-  Front  Door backend  pool  includes  both  App Gateway  public  IPs.
-  Health probe  path  /healthz  returns  200.

##  Steps
1.  Scale primary  gateway  to  zero  replicas:
     ```bash
     kubectl  scale  deploy/gateway -n  archref  --replicas=0
     ```
2.  Confirm  Front Door  fails  traffic  to  secondary.
3.  Restore  replicas  to  2:
     ```bash
     kubectl  scale  deploy/gateway -n  archref  --replicas=2
     ```
