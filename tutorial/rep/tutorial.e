server postgres
    mypsql
;
server bash
    mybash
    yourbash
;

schedule Daily0000
  0 & 0 & * & * & * & *
;
schedule Test
#   minute & hour                           & day  & dayr & month    & weekday
    0      & 0,2,4,6,8,10,12,14,16,18,20,22 & 1,15 & *    & 1-3,9-12 & *
|   0      & 0,2,4,6,8,10,12,14,16,18,20,22 & *    & 1,2  & 1-3,9-12 & *
|   30     & 1,3,5,7,9,11,13,15,17,19,21,23 & 5,10 & *    & 4-8      & *
|   30     & 1,3,5,7,9,11,13,15,17,19,21,23 & *    & 1,3  & 4-8      & *
;

task main
with
#    Daily0000 = ( "0 0 0 \* \* \*" )
#  ,  
     ExetaHome         = /home/martin/Exeta/tutorial
  ,  MaxTimeStamp      = "9999-12-31 23:59:59"
submit same after 5 m when failed
submit next when succeeded
submit next when skipped
call ProvideExtracts
  || LoadEDW
;

task ProvideExtracts
with schedule  = Daily0000
#  ,  delay     = 0m
  ,  executor  = mybash
call ProvideExtracts.CzSO
;

task ProvideExtracts.CzSO
with Source = ${ExetaHome}/rmt/czso
  ,  Target = ${ExetaHome}/ext/czso
submit same after 10 m 3 times then skip when failed
submit next when succeeded
submit next when skipped
call Copy "${Source}/KLAS80004_CS.csv" "${Target}/KLAS80004_CS.\${TimeStamp[YYYYMMDDHH24MISS]}.dat"
  || Copy "${Source}/RES_CS.csv"       "${Target}/RES_CS.\${TimeStamp[YYYYMMDDHH24MISS]}.dat"
;

task LoadEDW
with schedule  = Daily0000
#  ,  delay     = 1h
  ,  executor  = mypsql
  ,  generator = mypsql
  ,  StgSchema = stg_layer
  ,  TgtSchema = tgt_layer
  ,  WrkSchema = wrk_area
call LoadStgLayer
  || LoadTgtLayer
;

task LoadStgLayer
with Retention = 14
  ,  Encoding  = UTF8
call LoadStgLayer.CzSO
;

task LoadStgLayer.CzSO
with Source    = czso
  ,  Retention = 7
  ,  Encoding  = WIN1250
call LoadStgTable ${Source}_klas80004_cs
       with Extract = KLAS80004_CS
  || LoadStgTable ${Source}_res_cs
       with Extract = RES_CS
;

task LoadStgTable Table
# Uses the following custom features:
#   StgSchema - a stage layer schema
#   ExtPath   - an extract path
#   Source    - a name of the source
#   Extract   - a name of the extract
#   Encoding  - an encoding of the extract
#   Retention - a number of extracts kept in the stage table
# These features must be set in some calling task.
# A value of the identifier Table is implicitly passed to all called tasks.
call LoadStgTable.DropNew   ${Table}    # Drop a new partition of the stage table if this partition already exists.
  -> LoadStgTable.CreateNew ${Table}    # Create a new partition of the stage table.
  -> LoadStgTable.LoadNew   ${Table}    # Load data into the new partition.
        submit same after 5 m 3 times then skip when failed
  -> LoadStgTable.CopyNew   ${Table}
        run when LoadStgTable.LoadNew ${Table} skipped
  -> (  LoadStgTable.AnalyzeNew ${Table} # Analyze the new partition.
     || LoadStgTable.DropOld    ${Table} # Drop
     )
;

task LoadStgTable.DropNew    Table call DropTable    ${StgSchema} "${Table}_\${TimeStamp[YYYYMMDDHH24MISS]}" ;
task LoadStgTable.AnalyzeNew Table call AnalyzeTable ${StgSchema} "${Table}_\${TimeStamp[YYYYMMDDHH24MISS]}" ;
task LoadStgTable.CreateNew  Table execute ;
task LoadStgTable.LoadNew    Table with executor = mybash generate once ;
task LoadStgTable.CopyNew    Table with executor = mybash generate always ;
task LoadStgTable.DropOld    Table skip when failed generate always ;

task LoadTgtLayer
with HistCols = "start_ts,end_ts"
call LoadTgtTable activity
       with IdList = "activity_id"
       run when LoadStgTable czso_klas80004_cs succeeded
  || LoadTgtTable party
       with IdList = "party_id"
       run when LoadStgTable czso_res_cs succeeded
  || LoadTgtTable party_activity
       with IdList = "party_id,activity_id"
       run when LoadTgtTable party succeeded
         &  LoadTgtTable activity succeeded
;

task LoadTgtTable Table
# Uses the following custom features:
#   WrkSchema - a schema for working (temporary) tables
#   StgSchema - a stage layer schema
#   TgtSchema - a target layer schema
#   IdList    - a list of columns with unique values in any point of history
#   HistCols  - columns containing start and end of a record validity
#   MaxTimeStamp - the maximal time stamp
# These features must be set before calling this task.
# A value of the identifier Table is implicitly passed to all called tasks.
call
  # GENERIC PART ##############################################################
     (  (  LoadTgtTable.DropNew   ${Table}
        -> LoadTgtTable.CreateNew ${Table}
        )
     || LoadTgtTable.DropTmp      ${Table}
     )
  # SPECIFIC PART #############################################################
  # the task LoadTgtTable.Transform.${Table}
  # need to be defined (in a specific file)
  # with a value substituted for the feature ${Table}
  -> LoadTgtTable.Transform.${Table}
  # GENERIC PART ##############################################################
  -> (  (  LoadTgtTable.DropDel ${Table} -> LoadTgtTable.CreateDel ${Table} )
     || (  LoadTgtTable.DropIns ${Table} -> LoadTgtTable.CreateIns ${Table} )
     || (  LoadTgtTable.DropUpd ${Table} -> LoadTgtTable.CreateUpd ${Table} )
     )
  -> LoadTgtTable.LoadDel ${Table}
  -> LoadTgtTable.LoadIns ${Table}
;

task LoadTgtTable.DropTmp   Table generate always ;
task LoadTgtTable.DropNew   Table call DropTable ${WrkSchema} ${Table}_n ;
task LoadTgtTable.DropDel   Table call DropTable ${WrkSchema} ${Table}_d ;
task LoadTgtTable.DropIns   Table call DropTable ${WrkSchema} ${Table}_i ;
task LoadTgtTable.DropUpd   Table call DropTable ${WrkSchema} ${Table}_u ;
task LoadTgtTable.CreateNew Table execute ;
task LoadTgtTable.CreateDel Table execute ;
task LoadTgtTable.CreateIns Table execute ;
task LoadTgtTable.CreateUpd Table generate once ;
task LoadTgtTable.LoadDel   Table execute ;
task LoadTgtTable.LoadIns   Table execute ;

task Copy         Source Target execute ;
task AnalyzeTable Schema Table  execute ;
task DropTable    Schema Table  skip when failed execute ;

# BEGIN activity
task LoadTgtTable.Transform.activity execute ;
# END activity

# BEGIN party
task LoadTgtTable.Transform.party execute ;
# END party

# BEGIN party_activity
task LoadTgtTable.Transform.party_activity
call LoadTgtTable.Transform.party_activity.T01
  -> LoadTgtTable.Transform.party_activity.New
;
task LoadTgtTable.Transform.party_activity.T01 execute ;
task LoadTgtTable.Transform.party_activity.New execute ;
# END party_activity
