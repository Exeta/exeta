update ${TgtSchema}.${Table}
set end_ts = to_char(to_timestamp('\${TimeStamp[YYYY-MM-DD HH24:MI:SS]}', 'YYYY-MM-DD HH24:MI:SS')
where   (${IdList}) in (select ${IdList} from ${WrkSchema}.${Table}_d)
    or  (${IdList}) in (select ${IdList} from ${WrkSchema}.${Table}_u)
;
