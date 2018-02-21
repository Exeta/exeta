create table ${WrkSchema}.${Table}_i
as
(
select *
from ${WrkSchema}.${Table}_t
where (${IdList}) not in
    (
    select ${IdList}
    from ${TgtSchema}.${Table}
    where   to_char(to_timestamp('\${TimeStamp[YYYY-MM-DD HH24:MI:SS]}', 'YYYY-MM-DD HH24:MI:SS') >= start_ts
        and to_char(to_timestamp('\${TimeStamp[YYYY-MM-DD HH24:MI:SS]}', 'YYYY-MM-DD HH24:MI:SS') <  end_ts
    )
)
with data
;
