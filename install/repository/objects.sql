set schema 'exeta';

/******************************************************************************/
/* REFERENCE TABLES                                                           */
/******************************************************************************/

create table r_server_usage_type
(   id integer not null
,   code char(1) not null
,   name text not null
--
,   primary key (id)
,   unique (code)
,   unique (name)
)
;
insert into r_server_usage_type (id, code, name) values
    (0, 'G', 'generator')
,   (1, 'E', 'executor')
;
create table r_task_type
--
(   id   integer not null
,   code char(2) not null
,   name text    not null
--
,   primary key (id)
,   unique (code)
,   unique (name)
)
;
insert into r_task_type (id, code, name) values
    (0, 'C', 'call')
,   (1, 'E', 'execute')
,   (2, 'GO', 'generate once')
,   (3, 'GA', 'generate always')
;
create table r_rule_type
--
(   id integer not null
,   name text not null
--
,   primary key (id)
,   unique (name)
)
;
insert into r_rule_type (id, name) values
    (0, 'failed')
,   (1, 'succeeded')
,   (2, 'skipped')
;
create table r_action
--
(   id   integer not null
,   name text    not null
--
,   primary key (id)
,   unique (name)
)
;
insert into r_action (id, name) values
    (0, 'succeed')
,   (1, 'skip')
,   (2, 'suspend')
,   (3, 'fail caller')
,   (4, 'submit same')
,   (5, 'submit next')
,   (6, 'submit future')
;
create table r_time_unit
--
(   id   integer not null
,   code char(1) not null
,   name text    not null
--
,   primary key (id)
,   unique (code)
,   unique (name)
)
;
insert into r_time_unit (id, code, name) values
    (0, 's', 'second')
,   (1, 'm', 'minute')
,   (2, 'h', 'hour')
;
 create table r_status
 --
 (  id integer not null
 ,  name text not null
 --
 ,  primary key (id)
 ,  unique (name)
 )
 ;
 insert into r_status (id, name) values
    (0, 'submitted')
,   (1, 'running')
,   (2, 'failed')
,   (3, 'succeeded')
,   (4, 'skipped')
,   (5, 'suspended')
;
create table r_call_node_type
--
(   id   integer not null
,   code char(2) not null
,   name text    not null
--
,   primary key (id)
,   unique (code)
,   unique (name)
)
;
insert into r_call_node_type (id, code, name) values
    (0, '->', 'in sequence')
,   (1, '||', 'in parallel')
,   (2, '',  'atom')
;
create table r_condition_node_type
--
(   id   integer not null
,   code char(1) not null
,   name text    not null
--
,   primary key (id)
,   unique (code)
,   unique (name)
)
;
insert into r_condition_node_type (id, code, name) values
    (0, '&', 'and')
,   (1, '|', 'or')
,   (2, '', 'atom')
;
/*
create table message_type
--
(   id   integer not null
,   name text    not null
--
,   primary key (id)
,   unique (name)
)
;
insert into message_type (id, name) values
    (0, 'error')
,   (1, 'warning')
;
*/
create table r_identifier_type
--
(   id   integer not null
,   name text    not null
--
,   primary key (id)
,   unique (name)
)
;
insert into r_identifier_type (id, name) values
    (0, 'ordinary')
,   (1, 'list')
,   (2, 'member')
;
create table r_schedule_node_type
(   id integer
,   code varchar(3) not null
,   name text not null
--
,   primary key (id)
,   unique (code)
)
;
insert into r_schedule_node_type (id, code, name)
values
    ( 1, 'n', 'minute' )
,   ( 2, 'h', 'hour' )
,   ( 3, 'd', 'day of month' )
,   ( 4, 'r', 'day of month reverse' )
,   ( 5, 'm', 'month' )
,   ( 6, 'w', 'day of week' )
;

/******************************************************************************/
/* INTERFACE TABLES                                                           */
/******************************************************************************/

create table i_language
(   id integer not null
,   name text not null
--
,   primary key (id)
,   unique (name)
)
;
create table i_server
(   id integer not null
,   name text not null
,   language_id integer not null
--
,   primary key (id)
,   unique (name)
,   foreign key (language_id) references i_language
)
;
create table i_schedule
(   id   integer not null
,   name text    not null
--
,   primary key (id)
,   unique (name)
)
;
create table i_schedule_node
(   schedule_id           integer not null
,   position              integer
,   schedule_node_type_id integer not null
,   value                 integer not null
--
--,   unique (schedule_id, position, schedule_node_type_id, value)
,   foreign key (schedule_id) references i_schedule
,   foreign key (schedule_node_type_id) references r_schedule_node_type
)
;
create table i_task
--
(   id           integer not null
,   name         text    not null
,   task_type_id integer not null
--
,   primary key (id)
,   unique (name)
,   foreign key (task_type_id) references r_task_type
)
;
create table i_call
--
(   task_id integer not null
,   id      integer not null
,   name    text    not null
--
,   primary key (task_id, id)
,   foreign key (task_id) references i_task
)
;
create table i_identifier_name
--
(   task_id            integer not null
,   position           integer not null
,   name               text    not null
,   identifier_type_id integer not null
--
,   primary key (task_id, position)
,   unique (task_id, name)
,   foreign key (task_id) references i_task
,   foreign key (identifier_type_id) references r_identifier_type
)
;
create table i_identifier_value
--
(   task_id  integer not null
,   call_id  integer not null
,   position integer not null
,   value    text    not null
--
,   primary key (task_id, call_id, position)
,   foreign key (task_id, call_id) references i_call
)
;
create table i_feature
--
(   task_id  integer not null
,   call_id  integer
,   position integer not null
,   name     text    not null
,   value    text    not null
--
,   unique (task_id, call_id, position)
,   foreign key (task_id) references i_task
,   foreign key (task_id, call_id) references i_call
)
;
create table i_rule
--
(   task_id      integer not null
,   call_id      integer
,   rule_type_id integer not null
,   position     integer not null
,   action_id    integer not null
,   time         integer
,   time_unit_id integer
,   iteration    integer
--
,   unique (task_id, call_id, rule_type_id, position)
,   foreign key (task_id) references i_task
,   foreign key (task_id, call_id) references i_call
,   foreign key (rule_type_id) references r_rule_type
,   foreign key (action_id) references r_action
,   foreign key (time_unit_id) references r_time_unit
)
;
create table i_call_node
--
(   task_id           integer not null
,   id                integer not null
,   parent_id         integer
,   position          integer not null
,   call_node_type_id integer not null
,   call_id           integer
--
,   primary key (task_id, id)
,   unique (task_id, parent_id, position)
,   unique (task_id, call_id)
,   foreign key (task_id, parent_id) references i_call_node
,   foreign key (task_id) references i_task
,   foreign key (call_node_type_id) references r_call_node_type
,   foreign key (task_id, call_id) references i_call
,   check
    (   call_node_type_id =  2 and call_id is not null -- call atom
    or  call_node_type_id <> 2 and call_id is     null -- in sequence/in parallel
    )
)
;
create table i_condition_node
--
(   task_id                integer not null
,   call_id                integer
,   id                     integer not null
,   parent_id              integer
,   position               integer not null
,   condition_node_type_id integer not null
,   condition_call_id      integer
,   status_id              integer
,   time                   integer
,   time_unit_id           integer
--
,   unique (task_id, call_id, id)
,   unique (task_id, call_id, parent_id, position)
,   unique (task_id, condition_call_id)
,   foreign key (task_id) references i_task
,   foreign key (task_id, call_id) references i_call
,   foreign key (task_id, call_id, parent_id) references i_condition_node (task_id, call_id, id)
,   foreign key (condition_node_type_id) references r_condition_node_type
,   foreign key (task_id, condition_call_id) references i_call
,   foreign key (status_id) references r_status
,   foreign key (time_unit_id) references r_time_unit
,   check
    (   /*atom  */ condition_node_type_id =  2 and condition_call_id is not null and status_id in (0, 1, 2, 3)
    or  /*atom  */ condition_node_type_id =  2 and condition_call_id is not null and status_id in (4, 5)       and time is null and time_unit_id is null
    or  /*and/or*/ condition_node_type_id <> 2 and condition_call_id is     null and status_id is null         and time is null and time_unit_id is null
    )
)
;

/******************************************************************************/
/* DERIVED INTERFACE TABLES                                                   */
/******************************************************************************/

create table d_instance
--
(   id         integer not null
,   parent_id  integer
,   call_id    integer
,   task_id    integer not null
,   identifier text[]
--
,   primary key (id)
,   unique (task_id, identifier)
,   foreign key (parent_id) references d_instance
,   foreign key (task_id) references i_task
)
;
create table d_file
--
(   instance_id integer not null
,   name        text    not null
--
,   primary key (instance_id)
,   unique (name)
,   foreign key (instance_id) references d_instance
)
;
create table d_condition
--
(   instance_id integer not null
,   call_id     integer not null
,   task_id     integer not null
,   identifier  text[]
--
,   primary key (instance_id, call_id)
,   foreign key (instance_id) references d_instance
,   foreign key (task_id) references i_task
)
;
create table d_feature
--
(   instance_id integer not null
,   name        text    not null
,   value       text    not null
,   assignment  text    not null
--
,   primary key (instance_id, name)
,   foreign key (instance_id) references d_instance
)
;

/******************************************************************************/
/* PERMANENT TABLES                                                           */
/******************************************************************************/

create table p_language
(   id integer not null
,   name text not null
--
,   primary key (id)
,   unique (name)
)
;
create table p_server
(   id integer not null
,   name text not null
,   language_id integer not null
--
,   primary key (id)
,   unique (name)
,   foreign key (language_id) references p_language
)
;
create table p_schedule
(   id   integer not null
,   name text    not null
--
,   primary key (id)
,   unique (name)
)
;
create table p_schedule_node
(   schedule_id           integer not null
,   position              integer
,   schedule_node_type_id integer not null
,   value                 integer not null
--
,   primary key (schedule_id, position, schedule_node_type_id, value)
,   foreign key (schedule_id) references p_schedule
,   foreign key (schedule_node_type_id) references r_schedule_node_type
)
;
create table p_task
--
(   id           serial
,   name         text
,   task_type_id integer not null
--
,   primary key (id)
,   unique (name)
,   foreign key (task_type_id) references r_task_type
)
;
create table p_call_node
--
(   task_id           integer not null
,   id                integer not null
,   parent_id         integer
,   position          integer not null
,   call_node_type_id integer not null
,   call_id           integer
--
,   primary key (task_id, id)
,   unique (task_id, parent_id, position)
,   unique (task_id, call_id)
,   foreign key (task_id, parent_id) references p_call_node
,   foreign key (task_id) references p_task
,   foreign key (call_node_type_id) references r_call_node_type
,   check
    (   call_node_type_id =  2 and call_id is not null -- call atom
    or  call_node_type_id <> 2 and call_id is     null -- in sequence/in parallel
    )
)
;
create table p_condition_node
--
(   task_id                integer not null
,   call_id                integer
,   id                     integer not null
,   parent_id              integer
,   position               integer not null
,   condition_node_type_id integer not null
,   condition_call_id      integer
,   status_id              integer
,   time                   integer
,   time_unit_id           integer
--
,   unique (task_id, call_id, id)
,   unique (task_id, call_id, parent_id, position)
,   unique (task_id, condition_call_id)
,   foreign key (task_id) references p_task
,   foreign key (task_id, call_id, parent_id) references p_condition_node (task_id, call_id, id)
,   foreign key (condition_node_type_id) references r_condition_node_type
,   foreign key (status_id) references r_status
,   foreign key (time_unit_id) references r_time_unit
,   check
    (   /*atom  */ condition_node_type_id =  2 and condition_call_id is not null and status_id in (0, 1, 2, 3)
    or  /*atom  */ condition_node_type_id =  2 and condition_call_id is not null and status_id in (4, 5)       and time is null and time_unit_id is null
    or  /*and/or*/ condition_node_type_id <> 2 and condition_call_id is     null and status_id is null         and time is null and time_unit_id is null
    )
)
;
create table p_instance
--
(   id           serial
,   parent_id    integer
,   call_id      integer
,   task_id      integer not null
,   identifier   text[]
,   schedule_id  integer
,   executor_id  integer
,   generator_id integer
--
,   primary key (id)
,   unique (task_id, identifier)
,   foreign key (parent_id) references p_instance
,   foreign key (task_id) references p_task
,   foreign key (schedule_id) references p_schedule
,   foreign key (executor_id) references p_server
,   foreign key (generator_id) references p_server
)
;
create table p_instance_server
(   instance_id          integer not null
,   server_usage_type_id integer not null
,   server_id            integer not null
--
,   primary key (instance_id, server_usage_type_id)
,   foreign key (instance_id) references p_instance
,   foreign key (server_usage_type_id) references r_server_usage_type
,   foreign key (server_id) references p_server
)
;
create table p_file
--
(   instance_id integer not null
,   name        text    not null
--
,   primary key (instance_id)
,   unique (name)
,   foreign key (instance_id) references p_instance
)
;
create table p_condition
--
(   instance_id integer not null
,   call_id     integer not null
,   task_id     integer not null
,   identifier  text[]
--
,   primary key (instance_id, call_id)
,   foreign key (instance_id) references p_instance
,   foreign key (task_id) references p_task
)
;
create table p_feature
--
(   instance_id integer not null
,   name        text    not null
,   value       text    not null
,   assignment  text    not null
--
,   primary key (instance_id, name)
,   foreign key (instance_id) references p_instance
)
;

/******************************************************************************/
/* LOG TABLES                                                                 */
/******************************************************************************/

create table l_run
--
(   id          serial   
,   instance_id integer   not null
,   run_ts      timestamp not null
--
,   primary key (id)
,   unique      (instance_id, run_ts)
,   foreign key (instance_id) references p_instance
)
;
create table l_run_status
--
(   run_id    integer   not null
,   log_ts    timestamp not null
,   status_id integer   not null
--
,   primary key (run_id, log_ts)
,   foreign key (run_id) references l_run
,   foreign key (status_id) references r_status
)
;

/******************************************************************************/
/* VIEWS AND FUNCTIONS                                                        */
/******************************************************************************/

create view p_instance_tree as
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
        end as node
from r
left outer join p_instance as i on i.parent_id = r.instance_id and i.call_id = r.call_node_call_id
left outer join p_task as t on t.id = i.task_id
left outer join r_call_node_type as c on c.id = r.call_node_type_id
union all
select array[]::integer[], 'main'
order by 1
;
create view p_condition_tree as
with recursive
    x (path, task_id, call_id, id, condition_node_type_id, condition_call_id, status_id, time, time_unit_id) as
        (
        select array[]::integer[], task_id, call_id, id, condition_node_type_id, condition_call_id, status_id, time, time_unit_id
        from p_condition_node
        where parent_id is null
        union all
        select x.path || t.id, x.task_id, x.call_id, t.id, t.condition_node_type_id, t.condition_call_id, t.status_id, t.time, t.time_unit_id
        from x
        inner join p_condition_node as t on t.task_id = x.task_id and (t.call_id = x.call_id or t.call_id is null and x.call_id is null) and t.parent_id = x.id
        )
select
    ic.id as dependent_instance_id
,   x.path
,   ii.id as instance_id
,   x.condition_node_type_id
,   x.status_id
,   x.time
,   x.time_unit_id
from x
inner      join p_instance  as it on it.task_id = x.task_id
inner      join p_instance  as ic on ic.parent_id = it.id and (ic.call_id = x.call_id or ic.call_id is null and x.call_id is null)
left outer join p_condition as cx on cx.instance_id = ic.id and cx.call_id = x.condition_call_id
left outer join p_instance  as ii on ii.task_id = cx.task_id and ii.identifier = cx.identifier
order by 1, 2
;

-- Jak je to s prechodem letni <-> zimni cas?

create or replace function f_all_candidate_dates
(   p_start_date         date    
,   p_direction          integer 
)
returns table
(   seq                  integer
,   year                 integer
,   month                integer
,   day_of_month         integer
,   day_of_month_reverse integer
,   day_of_week          integer
)
as
$$
with recursive
    x (seq) as
        (
        select cast(0 as integer)
        union all
        select seq + 1 from x where seq <= 4 * 366
        )
select
    seq
,   cast(extract(year  from dt) as integer)
,   cast(extract(month from dt) as integer)
,   cast(extract(day   from dt) as integer)
,   cast
    (   
        cast
        (   case extract(month from dt)
                when 12
                then (extract(year from dt) + 1) || '-01-01'
                else (extract(year from dt)    ) || '-' || (extract(month from dt) + 1) || '-01'
            end
            as date
        )
    -   dt
    as integer
    )
,   cast(extract(isodow from dt) as integer)
from
    (
    select
        p_start_date + seq * p_direction as dt
    ,   seq
    from x
    ) as t
;
$$
language sql
;

create or replace view v_schedule_dates
as
select m.schedule_id, m.position, d.value as day_of_month, r.value as day_of_month_reverse, m.value as month, w.value as day_of_week
from       (select schedule_id, position, value from p_schedule_node where schedule_node_type_id = 3) as d
inner join (select schedule_id, position, value from p_schedule_node where schedule_node_type_id = 4) as r on r.schedule_id = d.schedule_id and r.position = d.position
inner join (select schedule_id, position, value from p_schedule_node where schedule_node_type_id = 5) as m on m.schedule_id = d.schedule_id and m.position = d.position
inner join (select schedule_id, position, value from p_schedule_node where schedule_node_type_id = 6) as w on w.schedule_id = d.schedule_id and w.position = d.position
;

create or replace function f_limited_candidate_dates
(   p_schedule_id        integer
,   p_start_date         date
,   p_direction          integer /* -1 = backward, +1 = forward */
)
returns table
(   year                 integer
,   month                integer
,   day_of_month         integer
,   day_of_month_reverse integer
,   day_of_week          integer
)
as
$$
select t.year, t.month, t.day_of_month, t.day_of_month_reverse, t.day_of_week
from
    (
    select distinct
        make_date(d.year, d.month, d.day_of_month) as dt
    ,   ((d.year * 100 + d.month) * 100 + d.day_of_month) as seq
    ,   d.year, d.month, d.day_of_month, d.day_of_month_reverse, d.day_of_week
    from f_all_candidate_dates(p_start_date, p_direction) as d
    inner join v_schedule_dates as s
       on      s.schedule_id = p_schedule_id
           and s.day_of_month = d.day_of_month
           and s.day_of_month_reverse = d.day_of_month_reverse
           and s.month = d.month
           and s.day_of_week = d.day_of_week
    ) as t
where   t.dt >= p_start_date and p_direction = +1
    or  t.dt <= p_start_date and p_direction = -1
order by p_direction * t.seq
limit 2
;
$$
language sql
;

create or replace view v_schedule_timestamps
as
select n.schedule_id, n.position, n.value as minute, h.value as hour, d.value as day_of_month, r.value as day_of_month_reverse, m.value as month, w.value as day_of_week
from       (select schedule_id, position, value from p_schedule_node where schedule_node_type_id = 1 /*minute              */) as n
inner join (select schedule_id, position, value from p_schedule_node where schedule_node_type_id = 2 /*hour                */) as h on h.schedule_id = n.schedule_id and h.position = n.position
inner join (select schedule_id, position, value from p_schedule_node where schedule_node_type_id = 3 /*day of month        */) as d on d.schedule_id = n.schedule_id and d.position = n.position
inner join (select schedule_id, position, value from p_schedule_node where schedule_node_type_id = 4 /*day of month reverse*/) as r on r.schedule_id = n.schedule_id and r.position = n.position
inner join (select schedule_id, position, value from p_schedule_node where schedule_node_type_id = 5 /*month               */) as m on m.schedule_id = n.schedule_id and m.position = n.position
inner join (select schedule_id, position, value from p_schedule_node where schedule_node_type_id = 6 /*day of week         */) as w on w.schedule_id = n.schedule_id and w.position = n.position
;

create or replace function f_schedule_timestamp
(   p_schedule_id     integer
,   p_start_timestamp timestamp with time zone
,   p_direction       integer                  /* -1 = backward, +1 = forward */
,   p_same_allowed    boolean                  /* true = start_timestamp can be returned, false = start_timestamp cannot be returned */
)
returns timestamp
as
$$
select ts
from
    (
    select distinct
        make_timestamp(d.year, d.month, d.day_of_month, s.hour, s.minute, 0) as ts
    ,   ((((cast(d.year as bigint) * 100 + d.month) * 100 + d.day_of_month) * 100) + s.hour) * 100 + s.minute as seq
    ,   d.year, d.month, d.day_of_month, s.hour, s.minute
    from f_limited_candidate_dates(p_schedule_id, cast(p_start_timestamp as date), p_direction) as d
    inner join v_schedule_timestamps as s
        on      s.schedule_id = p_schedule_id
            and s.day_of_month = d.day_of_month
            and s.day_of_month_reverse = d.day_of_month_reverse
            and s.month = d.month
            and s.day_of_week = d.day_of_week
    ) as t
where   t.ts > p_start_timestamp and p_direction = +1
    or  t.ts < p_start_timestamp and p_direction = -1
    or  t.ts = p_start_timestamp and p_same_allowed
order by p_direction * t.seq
limit 1
;
$$
language sql
;

create or replace function submit
(   p_task_name text
,   p_identifier text[]
,   p_timestamp timestamp with time zone
)
returns i_run.id%type
as
$$
declare
    l_instance_id p_instance.id%type;
begin
    select i.id into l_instance_id from p_instance as i inner join p_task as t on t.id = i.task_id where t.name = p_task_name and i.identifier = p_identifier;
    with recursive
    ;
end;
$$
language plpgsql
;
/*

Exeta engine submits task instances with fulfilled dependencies on servers of a heterogeneous computing environment.

Functions

Each of the following functions can be applied on any task instance.
If applied on an 'execute' or 'generate' task instance it is executed immediately.
If applied on a 'call' task instance it is applied recursively on called task instances.

generate
    Generates an executable code of 'generate once' task instance from its source code.
submit
run
    submits an os process that runs a task instance executable code
    - executes a script of task of type 'execute'
    - executes a generated script of task of type 'generate once'
    - executes a script of task of type 'generate always' and then execute)
  - 

check dependencies - both explicit (defined by 'when' clauses) and implicit (defined by '->' and '||')
check status
    Checks status of a task instance.
    First, in the log tables.
    If the status in the log tables is 'running' then checks the status of an os process in its log file else use status in the log tables.
    If the status in the log file is 'running' and the os process does not exist then 'failed' else use status in the log files.
*/

\q
