insert into ${WrkSchema}.${Table}_n (activity_id, start_ts, end_ts, source_id, name, description)
select
  coalesce(a.activity_id, nextval('${WrkSchema}.${Table}_s')
, to_timestamp('\${TimeStamp[YYYY-MM-DD HH24:MI:SS]}', 'YYYY-MM-DD HH24:MI:SS')
, to_timestamp('${MaxTimeStamp}', 'YYYY-MM-DD HH24:MI:SS')
, s.chodnota
from ${StgSchema}.czso_klas80004_cs_${TimeStamp} as s
left outer join (select distinct activity_id, source_id from ${TgtSchema}.${Table}) as a
  on  a.source_id = s.chodnota
where to_timestamp('\${TimeStamp[YYYY-MM-DD HH24:MI:SS]}', 'YYYY-MM-DD HH24:MI:SS') >= s.admplod
  and to_timestamp('\${TimeStamp[YYYY-MM-DD HH24:MI:SS]}', 'YYYY-MM-DD HH24:MI:SS') < s.admnepo
;
