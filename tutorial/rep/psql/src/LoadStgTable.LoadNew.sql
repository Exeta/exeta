select
    'cat ${ExtPath}/${Source}/${Extract}.\${TimeStamp[YYYYMMDDHH24MISS]}.dat | psql postgres --command "copy ${StgSchema}.${Table}_\${TimeStamp[YYYYMMDDHH24MISS]} ('
||  array_to_string(array_agg(attname),',')
||  ') from stdin with ( format csv, delimiter '';'', null '''', encoding ''${Encoding}'', header)"'
from
    (
    select cast(a.attname as text) as attname
    from pg_namespace as n
    inner join pg_class as c on c.relowner = n.nspowner
    inner join pg_attribute as a on a.attrelid = c.oid
    where n.nspname = 'stg_layer' and c.relname = lower('czso_KLAS80004_CS') and a.attnum > 0 and a.attname <> '_load_id'
    order by a.attnum
    ) as t
;
