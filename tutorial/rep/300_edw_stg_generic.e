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

call LoadStgTable.DropNew       # Drop a new partition of the stage table if this partition already exists. 
  -> LoadStgTable.CreateNew     # Create a new partition of the stage table.
  -> LoadStgTable.LoadNew       # Load data into the new partition.
        submit same after 5 m 3 times then skip when failed
  -> LoadStgTable.CopyNew
        when LoadStgTable.LoadNew skipped
  -> (  LoadStgTable.AnalyzeNew # Analyze the new partition.
     || LoadStgTable.DropOld    # Drop
     )
;

task LoadStgTable.DropNew Table
call DropTable ${StgSchema} ${Table}_${TimeStamp}
;
task LoadStgTable.AnalyzeNew Table
call AnalyzeTable ${StgSchema} ${Table}_${TimeStamp}
;
task LoadStgTable.CreateNew Table
execute
;
task LoadStgTable.LoadNew Table
generate once
;
task LoadStgTable.CopyNew Table
generate always
;
task LoadStgTable.DropOld Table
skip when failed
generate always
;

