insert into ${WrkSchema}.${Table}_n (party_id, order_num, activity_id, start_ts, end_ts)
select
    p.party_id
,   t01.order_num
,   a.activity_id
,   to_timestamp('\${TimeStamp[YYYY-MM-DD HH24:MI:SS]}', 'YYYY-MM-DD HH24:MI:SS')
,   to_timestamp('${MaxTimeStamp}', 'YYYY-MM-DD HH24:MI:SS')
from ${WrkSchema}.${Table}_t01 as t01
inner join ${TgtSchema}.party as p
    on  p.ico = t01.ico
    and to_timestamp('\${TimeStamp[YYYY-MM-DD HH24:MI:SS]}', 'YYYY-MM-DD HH24:MI:SS') >= p.start_ts
    and to_timestamp('\${TimeStamp[YYYY-MM-DD HH24:MI:SS]}', 'YYYY-MM-DD HH24:MI:SS') < p.end_ts
inner join ${TgtSchema}.activity as a
    on  a.nace_kl = t01.nace_kl
    and to_timestamp('\${TimeStamp[YYYY-MM-DD HH24:MI:SS]}', 'YYYY-MM-DD HH24:MI:SS') >= a.start_ts
    and to_timestamp('\${TimeStamp[YYYY-MM-DD HH24:MI:SS]}', 'YYYY-MM-DD HH24:MI:SS') < a.end_ts
;
