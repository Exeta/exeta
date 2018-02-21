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

  # GENERIC PART
  (  (  LoadTgtTable.DropNew -> LoadTgtTable.CreateNew  )
  || LoadTgtTable.DropTmp
  )

  # SPECIFIC PART
  # the task LoadTgtTable.Transform.${Table}
  # need to be defined (in a specific file)
  # with a value substituted for the feature ${Table}
  -> LoadTgtTable.Transform.${Table}

  # GENERIC PART
  -> (  (  LoadTgtTable.DropDel -> LoadTgtTable.CreateDel  )
     || (  LoadTgtTable.DropIns -> LoadTgtTable.CreateIns  )
     || (  LoadTgtTable.DropUpd -> LoadTgtTable.CreateUpd  )
     )
  -> LoadTgtTable.LoadDel
  -> LoadTgtTable.LoadIns
;

task LoadTgtTable.DropNew   Table call DropTable ${WrkSchema} ${Table}_n ;
task LoadTgtTable.DropDel   Table call DropTable ${WrkSchema} ${Table}_d ;
task LoadTgtTable.DropIns   Table call DropTable ${WrkSchema} ${Table}_i ;
task LoadTgtTable.DropUpd   Table call DropTable ${WrkSchema} ${Table}_u ;
task LoadTgtTable.DropTmp   Table generate once ;
task LoadTgtTable.CreateNew Table execute ;
task LoadTgtTable.CreateDel Table execute ;
task LoadTgtTable.CreateIns Table execute ;
task LoadTgtTable.CreateUpd Table generate once ;
task LoadTgtTable.LoadDel   Table execute ;
task LoadTgtTable.LoadIns   Table execute ;
