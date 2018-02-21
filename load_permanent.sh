psql postgres --tuples-only --no-align <<EOF
set schema 'exeta' ;

update p_instance set schedule_id = null, executor_id = null, generator_id = null;

\echo P_SERVER:
delete from p_server ;
\echo P_LANGUAGE:
delete from p_language ;
\echo P_SCHEDULE_NODE:
delete from p_schedule_node ;
\echo P_SCHEDULE:
delete from p_schedule ;

\echo P_LANGUAGE:
insert into p_language (id, name) select id, name from i_language ;
\echo P_SERVER:
insert into p_server (id, name, language_id) select id, name, language_id from i_server ;
\echo P_SCHEDULE:
insert into p_schedule (id, name) select id, name from i_schedule ;
\echo P_SCHEDULE_NODE:
insert into p_schedule_node (schedule_id, position, schedule_node_type_id, value) select distinct schedule_id, position, schedule_node_type_id, value from i_schedule_node ;
\echo P_TASK:
with
    upd (id) as
        (
        update p_task as p
        set task_type_id = i.task_type_id
        from i_task as i
        where p.name = i.name
        returning i.id
        )
,   ins (id) as
        (
        insert into p_task (name, task_type_id)
        select name, task_type_id
        from i_task as i
        where not exists
            (
            select null
            from p_task as p
            where p.name = i.name
            )
        returning id
        )
select 'UPDATE '||count(*) from upd
union all
select 'INSERT '||count(*) from ins
;
EOF
psql postgres --no-align <<EOF
set schema 'exeta' ;
\echo P_INSTANCE:
update p_instance
set parent_id = null
;
EOF
psql postgres --tuples-only --no-align <<EOF
set schema 'exeta' ;
with
    upd (id) as
        (
        update p_instance as pi
        set call_id = ii.call_id, schedule_id = s.id, executor_id = se.id, generator_id = sg.id
        from d_instance as ii
        inner join i_task as it on it.id = ii.task_id
        inner join p_task as pt on pt.name = it.name
        --
        left outer join d_feature as f on f.instance_id = ii.id and f.name = 'schedule'
        left outer join i_schedule as s on s.name = f.value
        --
        left outer join d_feature as fe on fe.instance_id = ii.id and fe.name = 'executor'
        left outer join i_server as se on se.name = fe.value
        --
        left outer join d_feature as fg on fg.instance_id = ii.id and fg.name = 'generator'
        left outer join i_server as sg on sg.name = fg.value
        --
        where pi.task_id = pt.id and pi.identifier = ii.identifier
        returning pi.id
        )
,   ins (id) as
        (
        insert into p_instance (call_id, task_id, identifier, schedule_id, executor_id, generator_id)
        select ii.call_id, pt.id, ii.identifier, s.id, se.id, sg.id
        from d_instance as ii
        inner join i_task as it on it.id = ii.task_id
        inner join p_task as pt on pt.name = it.name
        left outer join p_instance as pi on pi.task_id = pt.id and pi.identifier = ii.identifier
        --
        left outer join d_feature as f on f.instance_id = ii.id and f.name = 'schedule'
        left outer join i_schedule as s on s.name = f.value
        --
        left outer join d_feature as fe on fe.instance_id = ii.id and fe.name = 'executor'
        left outer join i_server as se on se.name = fe.value
        --
        left outer join d_feature as fg on fg.instance_id = ii.id and fg.name = 'generator'
        left outer join i_server as sg on sg.name = fg.value
        --
        where pi.id is null
        returning id
        )
select 'UPDATE '||count(*) from upd
union all
select 'INSERT '||count(*) from ins
;
EOF
psql postgres --no-align <<EOF
set schema 'exeta';
update p_instance as pi
set parent_id = ppi.id
from d_instance as ii
inner join i_task as it on it.id = ii.task_id
inner join p_task as pt on pt.name = it.name
inner join d_instance as ipi on ipi.id = ii.parent_id
inner join i_task as ipt on ipt.id = ipi.task_id
inner join p_task as ppt on ppt.name = ipt.name
inner join p_instance as ppi on ppi.task_id = ppt.id and ppi.identifier = ipi.identifier
where pi.task_id = pt.id and pi.identifier = ii.identifier
;
\echo P_CONDITION:
delete from p_condition where instance_id in (select x.id from p_instance as x inner join p_task as p on p.id = x.task_id inner join i_task as i on i.name = p.name)
;
insert into p_condition (instance_id, call_id, task_id, identifier)
select pi.id, dc.call_id, pt.id, dc.identifier
from       d_condition as dc
inner join i_task      as it on it.id = dc.task_id
inner join p_task      as pt on pt.name = it.name
inner join d_instance  as di on di.id = dc.instance_id
inner join i_task      as ix on ix.id = di.task_id
inner join p_task      as px on px.name = ix.name
inner join p_instance  as pi on pi.task_id = px.id and pi.identifier = di.identifier
;
\echo P_FILE:
delete from p_file where instance_id in (select x.id from p_instance as x inner join p_task as p on p.id = x.task_id inner join i_task as i on i.name = p.name)
;
insert into p_file (instance_id, name)
select pi.id, if.name
from d_file as if
inner join d_instance as ii on ii.id = if.instance_id
inner join i_task as it on it.id = ii.task_id
inner join p_task as pt on pt.name = it.name
inner join p_instance as pi on pi.task_id = pt.id and pi.identifier = ii.identifier
;
\echo P_CALL_NODE:
delete from p_call_node where task_id in (select p.id from p_task as p inner join i_task as i on i.name = p.name)
;
/*
insert into p_call_node (task_id, id, parent_id, position, call_node_type_id, call_id)
select p.id, n.id, n.parent_id, n.position, n.call_node_type_id, n.call_id
from i_call_node as n
inner join i_task as i on i.id = n.task_id
inner join p_task as p on p.name = i.name
;
*/
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
insert into p_call_node (task_id, id, parent_id, position, call_node_type_id, call_id)
select
    p.id
,   x.id
,   x.parent_id
,   rank() over (partition by x.task_id, x.parent_id order by x.position * 2 ^ (y.max_depth - x.depth)) - 1
,   x.call_node_type_id
,   x.call_id
from x
inner join y on y.task_id = x.task_id
inner join i_task as i on i.id = x.task_id
inner join p_task as p on p.name = i.name
where x.valid
;
\echo P_CONDITION_NODE:
delete from p_condition_node where task_id in (select p.id from p_task as p inner join i_task as i on i.name = p.name)
;
/*
insert into p_condition_node (task_id, call_id, id, parent_id, position, condition_node_type_id, condition_call_id, status_id, time, time_unit_id)
select p.id, n.call_id, n.id, n.parent_id, n.position, n.condition_node_type_id, n.condition_call_id, n.status_id, n.time, n.time_unit_id
from i_condition_node as n
inner join i_task as i on i.id = n.task_id
inner join p_task as p on p.name = i.name
;
*/
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
insert into p_condition_node (task_id, call_id, id, parent_id, position, condition_node_type_id, condition_call_id, status_id, time, time_unit_id)
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
;
EOF
