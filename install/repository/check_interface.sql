set schema 'exeta'
;
with recursive
    x (path, id, task_id, identifier) as
    (
    select array[]::integer[], id, task_id, identifier
    from d_instance
    where parent_id is null
    union all
    select x.path || i.id, i.id, i.task_id, i.identifier
    from x
    inner join d_instance as i on i.parent_id = x.id
    )
select x.path, x.id, t.name, x.identifier
from x
inner join i_task as t on t.id = x.task_id
order by 1
;

-- RUN WHEN CONDITIONS

with
    recursive x (path, task_id, call_id, id, condition_node_type_id, condition_call_id, status_id, time, time_unit_id) as
    (
    select array[]::integer[], task_id, call_id, id, condition_node_type_id, condition_call_id, status_id, time, time_unit_id
    from i_condition_node
    where parent_id is null
    union all
    select x.path || t.id, x.task_id, x.call_id, t.id, t.condition_node_type_id, t.condition_call_id, t.status_id, t.time, t.time_unit_id
    from x
    inner join i_condition_node as t on t.task_id = x.task_id and (t.call_id = x.call_id or t.call_id is null and x.call_id is null) and t.parent_id = x.id
    )
select
    i.id as instance_id
,   pi.task_id as dependent_task_id
,   it.name || coalesce(' ' || array_to_string(i.identifier, ' '), '') as dependent_task
,   x.path
,   cnt.code as condition_node_type
,   i.task_id as task_id
,   cit.name || coalesce(' ' || array_to_string(ci.identifier, ' '), '') as task
,   s.name as status
,   x.time
,   tu.name as time_unit
from            x
inner      join d_instance            as pi  on pi.task_id = x.task_id
inner      join d_instance            as i   on i.parent_id = pi.id and (i.call_id = x.call_id or i.call_id is null and x.call_id is null)
inner      join i_task                as it  on it.id = x.task_id
left outer join d_condition           as ci  on ci.instance_id = i.id and ci.call_id = x.condition_call_id
left outer join i_task                as cit on cit.id = ci.task_id
left outer join r_status              as s   on s.id = x.status_id
left outer join r_condition_node_type as cnt on cnt.id = x.condition_node_type_id and cnt.id <> 2
left outer join r_time_unit           as tu  on tu.id = x.time_unit_id
order by 1, 4
;

-- INSTANCE TREE

with
    recursive x (path, task_id, id, call_node_type_id, call_id) as
    (
    select array[]::integer[], task_id, id, call_node_type_id, call_id
    from i_call_node
    where parent_id is null
    union all
    select x.path || t.id, x.task_id, t.id, t.call_node_type_id, t.call_id
    from x
    inner join i_call_node as t on t.task_id = x.task_id and t.parent_id = x.id
    )
select pi.id as parent_instance_id, pt.name as parent_task, pi.identifier as parent_identifier, x.path, cnt.code, ci.id as instance_id, ct.name as task, ci.identifier
from d_instance as pi
inner join i_task as pt on pt.id = pi.task_id
inner join x on x.task_id = pi.task_id
left outer join d_instance as ci on ci.parent_id = pi.id and ci.call_id = x.call_id
left outer join i_task as ct on ct.id = ci.task_id
left outer join r_call_node_type as cnt on cnt.id = x.call_node_type_id and cnt.id <> 2
order by 1, 4
;

