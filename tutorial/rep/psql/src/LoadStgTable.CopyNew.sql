with
  t (relname) as
  (
  select relname
  from
    (
    select
      cc.relname
    , rank() over (order by cc.relname desc) as rnk
    from pg_catalog.pg_inherits as i
    inner join pg_catalog.pg_class as cc on cc.oid = i.inhrelid
    inner join pg_catalog.pg_class as cp on cp.oid = i.inhparent
    inner join pg_catalog.pg_namespace as n on n.oid = cp.relnamespace
    where n.nspname = '${StgSchema}'
      and cp.relname = '${Table}'
    ) as t
  where rnk = 2
  )
, c (attnum, attname) as
    (
    select a.attnum, cast(a.attname as text)
    from pg_namespace as n
    inner join pg_class as c on c.relowner = n.nspowner
    inner join pg_attribute as a on a.attrelid = c.oid
    where n.nspname = '${StgSchema}'
      and c.relname = '${Table}'
      and a.attnum > 0
      and a.attname <> '_load_id'
    )
select tt.statement
from
  (
  select cast(0 as integer) as sttnum, cast(0 as integer) as attnum, cast('insert into ${StgSchema}.${Table}_\${TimeStamp[YYYYMMDDHH24MISS]}' as text) as statement
  from t
  union all
  select 1, attnum, case attnum when 1 then '(' else ',' end || ' ' || attname
  from c
  union all
  select 2, 0, ')
select'
  from t
  union all
  select 3, attnum, case attnum when 1 then ' ' else ',' end || ' ' || attname
  from c
  union all
  select 4, 0, 'from ' || relname || '
;'
  from t
  --where exists (select null from t)
  ) as tt
--where exists (select null from t)
order by tt.sttnum, tt.attnum
;
