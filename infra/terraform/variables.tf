variable  "prefix"  {
   description  =  "Resource name  prefix"
    type              =  string
}

variable  "location"  {
   description  =  "Primary  Azure region"
    type              =  string
   default         =  "westeurope"
}

variable "secondary_location"  {
    description =  "Secondary  Azure  region  (paired)"
   type              =  string
    default         = "northeurope"
}

variable  "sql_admin_password" {
    description  = "SQL  admin  password  (generated  if empty)"
    type              =  string
   sensitive      =  true
   default         =  ""
}
