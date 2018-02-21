task main
with Daily = ("0 0 \* \* \*")
#  ,  executor = DW
  ,  schedule = ${Daily}
  ,  pokus1 = \${Daily}
  ,  pokus2 = '\${Daily}'
call LoadTargetDaily
;
task LoadTargetDaily
call  LoadTable DW_DB DW_PRODUCT
      with List =
         ( CRM SCD2 "PROD_ID,START_TS"
           ERP SCD1 PROD_ID
           BS  SCD2 "PROD_ID,START_TS"
         )
;
task LoadTable Schema Table call LoadTableClone ; # WORKING
#task LoadTable Schema Table call LoadTableClone ${Schema} ${Table} ${List} ; # WORKING
#task LoadTable Schema Table call LoadTableClone ${Schema} ${Table} ( ${List[@]} ) ; # WORKING

task LoadTableClone Schema Table List : Source Method IdList
call  (  PrepWrk.${Method}
      -> LoadWrk.${Schema}.${Table}.${Source}
      -> LoadTgt.${Method}
      )
   || LoadTableClone
;
task PrepWrk.SCD1 Schema Table Source        generate ;
task PrepWrk.SCD2 Schema Table Source        generate ;
task LoadTgt.SCD1 Schema Table Source IdList generate ;
task LoadTgt.SCD2 Schema Table Source IdList generate ;

task LoadWrk.DW_DB.DW_PRODUCT.CRM execute ;
task LoadWrk.DW_DB.DW_PRODUCT.ERP execute ;
task LoadWrk.DW_DB.DW_PRODUCT.BS  execute ;
