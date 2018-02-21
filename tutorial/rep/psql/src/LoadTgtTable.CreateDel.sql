create table ${WrkSchema}.${Table}_d
as
(
select ${IdList}
from ${TgtSchema}.${Table}
where   to_char(to_timestamp('\${TimeStamp[YYYY-MM-DD HH24:MI:SS]}', 'YYYY-MM-DD HH24:MI:SS') >= start_ts
    and to_char(to_timestamp('\${TimeStamp[YYYY-MM-DD HH24:MI:SS]}', 'YYYY-MM-DD HH24:MI:SS') <  end_ts
    and (${IdList}) not in (select ${IdList} from ${WrkSchema}.${Table}_t)
)
with data
;
