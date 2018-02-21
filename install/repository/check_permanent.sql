set schema 'exeta'
;
/*
with recursive
    x (path, id, task_id, identifier) as
    (
    select array[]::integer[], id, task_id, identifier
    from p_instance
    where parent_id is null
    union all
    select x.path || i.id, i.id, i.task_id, i.identifier
    from x
    inner join p_instance as i on i.parent_id = x.id
    )
select x.path, x.id, t.name, x.identifier
from x
inner join p_task as t on t.id = x.task_id
order by 1
;
*/

-- INSTANCE TREE

/*
with
    recursive x (path, task_id, id, call_node_type_id, call_id) as
    (
    select array[]::integer[], task_id, id, call_node_type_id, call_id
    from p_call_node
    where parent_id is null
    union all
    select x.path || t.id, x.task_id, t.id, t.call_node_type_id, t.call_id
    from x
    inner join p_call_node as t on t.task_id = x.task_id and t.parent_id = x.id
    )
select pi.id as parent_instance_id, pt.name as parent_task, pi.identifier as parent_identifier, x.path, cnt.code, ci.id as instance_id, ct.name as task, ci.identifier
from            p_instance       as pi
inner      join p_task           as pt  on pt.id = pi.task_id
inner      join                     x   on x.task_id = pi.task_id
left outer join p_instance       as ci  on ci.parent_id = pi.id and ci.call_id = x.call_id
left outer join p_task           as ct  on ct.id = ci.task_id
left outer join r_call_node_type as cnt on cnt.id = x.call_node_type_id and cnt.id <> 2
order by 1, 4
;
*/

with recursive
    t (parent_instance_id, instance_id, parent_call_node_id, call_node_id, position, instance_call_id, task_id, call_node_type_id, call_node_call_id) as
        (
        select i.parent_id, i.id, cn.parent_id, cn.id, cn.position, i.call_id, i.task_id, cn.call_node_type_id, cn.call_id
        from p_instance as i
        inner join p_call_node as cn on cn.task_id = i.task_id
        )
,   r (path, instance_id, call_node_id, instance_call_id, task_id, call_node_type_id, call_node_call_id) as
        (
        select array[position]::integer[], instance_id, call_node_id, instance_call_id, task_id, call_node_type_id, call_node_call_id
        from t
        inner join p_task as p on p.id = t.task_id
        where parent_instance_id is null and parent_call_node_id is null and p.name = 'main'
        union all
        select
            r.path || t.position
        ,   t.instance_id
        ,   t.call_node_id
        ,   t.instance_call_id
        ,   t.task_id
        ,   t.call_node_type_id
        ,   t.call_node_call_id
        from r
        inner join t
        on t.parent_instance_id = r.instance_id and t.parent_call_node_id is null          and t.instance_call_id = r.call_node_call_id
        or t.instance_id        = r.instance_id and t.parent_call_node_id = r.call_node_id and t.task_id = r.task_id
        )
select
    r.path
,   lpad('', 2 * array_length(path, 1), ' ')
    ||  case c.id
            when 2
            then t.name || coalesce(' ' || array_to_string(i.identifier, ' '), '')
            else c.code
        end
from r
left outer join p_instance as i on i.parent_id = r.instance_id and i.call_id = r.call_node_call_id
left outer join p_task as t on t.id = i.task_id
left outer join r_call_node_type as c on c.id = r.call_node_type_id
union all
select array[]::integer[], 'main'
order by 1
;

-- RUN WHEN CONDITIONS

select
    c.*
--,   dt.name || coalesce(' ' || array_to_string(di.identifier, ' '), '') as dependent_instance
,   lpad('', 2 * coalesce(array_length(c.path, 1), 0), ' ')
    ||  coalesce(t.name, nt.code)
    ||  coalesce(' ' || array_to_string(i.identifier, ' '), '')
    ||  coalesce(' ' || s.name, '')
    ||  coalesce(' ' || c.time::text, '')
    ||  coalesce(' ' || u.code, '')
    as condition
from            p_condition_tree as c
--inner      join p_instance       as di on di.id = c.dependent_instance_id
--inner      join p_task           as dt on dt.id = di.task_id
left outer join p_instance       as i  on i.id = c.instance_id
left outer join p_task           as t  on t.id = i.task_id
left outer join r_condition_node_type as nt on nt.id = c.condition_node_type_id
left outer join r_status as s on s.id = c.status_id
left outer join r_time_unit as u on u.id = c.time_unit_id
order by 1, 2
;

