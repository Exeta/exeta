create table ${WrkSchema}.${Table}_t01
as
(
with recursive
    r (ICO, nace_kl, i, n, a) as
    (
    select
        ICO
    ,   a[1]
    ,   1
    ,   array_length(a, 1)
    ,   a
    from
        (
        select
            ICO
        ,   string_to_array(nace_kl, ' ') as a
        from ${StgSchema}.czso_res_cs_${TimeStamp}
        where to_timestamp('\${TimeStamp[YYYY-MM-DD HH24:MI:SS]}', 'YYYY-MM-DD HH24:MI:SS') >= admplod
          and to_timestamp('\${TimeStamp[YYYY-MM-DD HH24:MI:SS]}', 'YYYY-MM-DD HH24:MI:SS')  < admnepo
        ) as t
    where a is not null and a <> array[]::text[]
    union all
    select
        ICO
    ,   a[i + 1]
    ,   i + 1
    ,   n
    ,   a
    from r
    where i < n
    )
select
    ICO
,   i as order_num
,   nace_kl
from r
)
with data
;
