select
'create table ${WrkSchema}.${Table}_u
as
(
select src.*
from ${TgtSchema}.${Table} as tgt
inner join ${WrkSchema}.${Table}_t as src'
;
with recursive
    r (t, i, n, a) as
    (
    select
        a[1]
    ,   1
    ,   array_length(x.a, 1)
    ,   x.a
    from (select string_to_array('${IdList}', ',') as a) as x
    union all
    select
        r.a[r.i + 1]
    ,   r.i + 1
    ,   r.n
    ,   r.a
    from r
    where r.i < r.n
    )
select case i when 1 then '    on  ' else '    and ' end || 'src.' || t || ' = tgt.' || t
from r
order by i
;
select
    case i when 1 then 'where  ' else '    or ' end
||  'tgt.' || t || ' <> src.' || t
||  case when not_null
        then ''
        else ' or tgt.' || t || ' is null and src.' || t || ' is not null or tgt.' || t || ' is not null and src.' || t || ' is null'
    end
from
    (
    select dense_rank() over (order by a.attnum) as i, a.attname as t, a.attnotnull as not_null
    from pg_namespace as n
    inner join pg_class as c on c.relowner = n.nspowner
    inner join pg_attribute as a on a.attrelid = c.oid
    where   n.nspname = '${Schema}'
        and c.relname = '${Table}'
        and a.attnum > 0
        and not array[a.attname]::text[] <@ string_to_array('${IdList}', ',')
        and not array[a.attname]::text[] <@ string_to_array('${HistCols}', ',')
    ) as x
order by i
;
select t
from (select 'where false' as t) as x
where not exists
    (
    select null
    from pg_namespace as n
    inner join pg_class as c on c.relowner = n.nspowner
    inner join pg_attribute as a on a.attrelid = c.oid
    where   n.nspname = '${Schema}'
        and c.relname = '${Table}'
        and a.attnum > 0
        and not array[a.attname]::text[] <@ string_to_array('${IdList}', ',')
        and not array[a.attname]::text[] <@ string_to_array('${HistoryColumns}', ',')
    )
;
select
')
with data
;'
;
