task LoadTgtLayer
with HistCols = "start_ts,end_ts"
call LoadTgtTable activity
       with IdList = "activity_id"
       when LoadStgTable CzSO_KLAS80004_CS succeeded
  || LoadTgtTable party
       with IdList = "party_id"
       when LoadStgTable CzSO_RES_CS succeeded
  || LoadTgtTable party_activity
       with IdList = "party_id,activity_id"
       when LoadTgtTable party succeeded
         &  LoadTgtTable activity succeeded
;

# BEGIN activity
task LoadTgtTable.Transform.Activity execute ;
# END activity

# BEGIN party
task LoadTgtTable.Transform.Party execute ;
# END party

# BEGIN party_activity
task LoadTgtTable.Transform.PartyActivity
call LoadTgtTable.Transform.PartyActivity.T01
  -> LoadTgtTable.Transform.PartyActivity.New
;
task LoadTgtTable.Transform.PartyActivity.T01 execute ;
task LoadTgtTable.Transform.PartyActivity.New execute ;
# END party_activity
