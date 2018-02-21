insert into ${WrkSchema}.${Table}_n (party_id, start_ts, end_ts, source_id, name)
select
  coalesce(p.party_id, nextval('${WrkSchema}.${Table}_s')
, to_timestamp('\${TimeStamp[YYYY-MM-DD HH24:MI:SS]}', 'YYYY-MM-DD HH24:MI:SS')
, to_timestamp('${MaxTimeStamp}', 'YYYY-MM-DD HH24:MI:SS')
, s.ico
from ${StgSchema}.czso_res_cs_${TimeStamp} as s
left outer join (select distinct party_id, source_id from ${TgtSchema}.${Table}) as p
  on  p.source_id = s.ico
where to_timestamp('\${TimeStamp[YYYY-MM-DD HH24:MI:SS]}', 'YYYY-MM-DD HH24:MI:SS') >= s.admplod
  and to_timestamp('\${TimeStamp[YYYY-MM-DD HH24:MI:SS]}', 'YYYY-MM-DD HH24:MI:SS')  < s.admnepo
;
