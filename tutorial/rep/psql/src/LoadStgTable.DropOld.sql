select 'drop table ${StgSchema}.'||relname||';'
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
where rnk > ${Retention}
order by 1
;
/*
drop table ${StgSchema}.${Table}_\$(date --date="\${TimeStamp[YYYY-MM-DD]} -\${Retention} day" +%Y%m%d%H%M%S)
;
*/
