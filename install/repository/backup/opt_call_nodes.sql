with
    recursive x (task_id, id, parent_id, position, depth, call_node_type_id, call_id, valid) as
    (
    select task_id, id, parent_id, position, 0, call_node_type_id, call_id, true
    from i_call_node
    where parent_id is null

    union all
    
    select
        /*task_id          */ x.task_id
    ,   /*id               */ t.id
    ,   /*parent_id        */ case when x.valid then x.id else x.parent_id end
    ,   /*position         */ 2 * x.position + t.position
    ,   /*depth            */ x.depth + 1
    ,   /*call_node_type_id*/ t.call_node_type_id
    ,   /*call_id          */ t.call_id
    ,   /*valid            */ t.call_node_type_id <> x.call_node_type_id
    from x
    inner join i_call_node as t on t.task_id = x.task_id and t.parent_id = x.id
    )
,   y (task_id, max_depth) as
    (
    select task_id, max(depth)
    from x
    group by task_id
    )
select
    x.task_id
,   x.id
,   x.parent_id
,   rank() over (partition by x.task_id, x.parent_id order by x.position * 2 ^ (y.max_depth - x.depth)) - 1 as position
,   x.call_node_type_id
,   x.call_id
,   t.name
,   n.code
,   c.name
from x
inner join y on y.task_id = x.task_id
inner join i_task as t on t.id = x.task_id
inner join r_call_node_type as n on n.id = x.call_node_type_id
left outer join i_call as c on c.task_id = x.task_id and c.id = x.call_id
where x.valid
order by 1, 3, 4
;
with
    recursive x (task_id, call_id, id, parent_id, position, depth, condition_node_type_id, condition_call_id, status_id, time, time_unit_id, valid) as
    (
    select task_id, call_id, id, parent_id, position, 0, condition_node_type_id, condition_call_id, status_id, time, time_unit_id, true
    from i_condition_node
    where parent_id is null

    union all
    
    select
        /*task_id          */ x.task_id
    ,   /*call_id          */ x.call_id
    ,   /*id               */ t.id
    ,   /*parent_id        */ case when x.valid then x.id else x.parent_id end
    ,   /*position         */ 2 * x.position + t.position
    ,   /*depth            */ x.depth + 1
    ,   /*call_node_type_id*/ t.condition_node_type_id
    ,   /*condition_call_id*/ t.condition_call_id
    ,   /*status_id        */ t.status_id
    ,   /*time             */ t.time
    ,   /*time_unit_id     */ t.time_unit_id
    ,   /*valid            */ t.condition_node_type_id <> x.condition_node_type_id
    from x
    inner join i_condition_node as t on t.task_id = x.task_id and (t.call_id = x.call_id or t.call_id is null and x.call_id is null) and t.parent_id = x.id
    )
,   y (task_id, call_id, max_depth) as
    (
    select task_id, call_id, max(depth)
    from x
    group by task_id, call_id
    )
select
    p.id
,   x.call_id
,   x.id
,   x.parent_id
,   rank() over (partition by x.task_id, x.parent_id order by x.position * 2 ^ (y.max_depth - x.depth)) - 1 as position
,   x.condition_node_type_id
,   x.condition_call_id
,   x.status_id
,   x.time
,   x.time_unit_id
from x
inner join y on y.task_id = x.task_id and (y.call_id = x.call_id or y.call_id is null and x.call_id is null)
inner join i_task as i on i.id = x.task_id
inner join p_task as p on p.name = i.name
where x.valid
order by 1, 2, 4, 5
;
select pi.id as instance_id, x.task_id, x.path, cnt.code, t.name, i.identifier
from x
inner join r_call_node_type as cnt on cnt.id = x.call_node_type_id
inner join p_instance as pi on pi.task_id = x.task_id
left outer join p_instance as i on i.parent_id = pi.id and i.call_id = x.call_id
left outer join p_task as t on t.id = i.task_id
where x.valid
order by 1, 3
;

