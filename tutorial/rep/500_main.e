task main
with ScheduleDaily0000 = " 0 0 0 * * * "
  ,  ExtPath = ${EXETA_TUTORIAL_HOME}/ext
submit same after 5 m when failed
submit next when succeeded
submit next when skipped
call ProvideExtacts
  || LoadEDW
;

task ProvideExtracts
with schedule  = ${ScheduleDaily0000}
  ,  delay     = 0m
  ,  executor  = mybash
call ProvideExtracts.CzSO
;

task LoadEDW
with schedule  = ${ScheduleDaily0000}
  ,  delay     = 1h
  ,  executor  = mypsql
  ,  generator = mypsql
  ,  StgSchema = stg_layer
  ,  TgtSchema = tgt_layer
  ,  WrkSchema = wrk_area
call LoadStgLayer
  || LoadTgtLayer
;

