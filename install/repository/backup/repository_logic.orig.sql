set schema 'exeta'
;

/******************************************************************************/
/* Views                                                                      */
/******************************************************************************/

create or replace view instance_features_unnest
(   instance_id
--,   feature_number
,   feature_name
,   feature_value
)
as
select
    instance_id
,   (feature).name
,   (feature).value
from
    (
    select
        instance_id
    ,   unnest(features) as feature
    from instance_features
    ) as t
/*
(
with recursive x (instance_id, i, n) as 
(   select instance_id, 1, array_length(features, 1) 
    from instance_features
    where array_length(features, 1) > 0 
union all 
    select instance_id, i + 1, n 
    from x 
    where i < n
) 
select 
    x.instance_id
--,   x.i as feature_number
,   (t.features[i]).name
,   (t.features[i]).value
from x as x 
inner join instance_features as t 
    on t.instance_id = x.instance_id 
order by 1, 2
)
*/
;

/*
create or replace view instance_evaluations
as
(
with
    recursive x (instance_id_path, instance_id) as
    (
    select array[instance_id]::integer[], instance_id
    from instance_relations
    where dependent_instance_id is null
    union all
    select x.instance_id_path || r.instance_id, r.instance_id
    from x
    inner join instance_relations as r on r.dependent_instance_id = x.instance_id
    )
select x.instance_id_path, x.instance_id, i.task_name, i.identifiers, l.log_type as eval_log_type, l.message as eval_log_message
from x
inner join instances as i on i.instance_id = x.instance_id
left outer join evaluations as l on l.instance_id = x.instance_id
order by 1
)
;
*/

/******************************************************************************/
/* Functions                                                                  */
/******************************************************************************/

create or replace function normalized_value
(   in  value  text
,   out result text
)
as $$
declare
    i integer := 1;
    l integer := length(value);
begin
    result := '';
    while i <= l
    loop
        if substring(value from i for 1) = '\' /*'*/ then
            i := i + 1;
        end if;
        result = result || substring(value from i for 1);
        i := i + 1;
    end loop;
end
$$ language plpgsql
;

create or replace function enclosed_value
(   in  normalized_value text
,   out result           text
)
as $$
declare
    i integer := 1;
    l integer := length(normalized_value);
begin
    result := '"';
    while i <= l
    loop
        if substring(value from i for 1) = '"' then
            result = result || '\' /*'*/;
        end if;
        result = result || substring(value from i for 1);
        i := i + 1;
    end loop;
    result = result || '"';
end
$$ language plpgsql
;

/*
There are 2 types of values:
* atomic (literal) - optionaly enclosed by " and "
* compound (list) - enclosed by ( and ) - list of atomic/compound values

list1=("A" "B" "C" "D")
list2=("1" "2" "3" ${list1} "4" "5")
list3=("e" "f" "g" "h" "i" "j")
list4=(${list1} ${list3})
list5=${list1} ${list3} -- incorrect syntax

What is a result of substitution of list1 into list2?
Is it
list2=("1" "2" "3"  "A" "B" "C" "D"  "4" "5")
or
list2=("1" "2" "3" ("A" "B" "C" "D") "4" "5")
?
The first option is prefered as the second one can be expressed as follows:
list2=("1" "2" "3" ( ${list1} ) "4" "5")

A list can be substituted into a literal. E.g.,
list1=( "A" "B" "C" "D" )
list2=( "1" "2" "3" ( ${list1} ) "4" "5" ) -> ( "1" "2" "3" ("A" "B" "C" "D") "4" "5" )
literal="a b c ${list1} d e" -> "a b c 123ABCD45 d e"
                                       |  |__| |
                                       | list1 |
                                       |_______|
                                         list2
When a list is substituted into a literal its entire structure is lost.

From the point of view of substitution and list operations (head and tail), ( "A" ), a list consisting of just one literal "A", is the same as literal "A" itself and an empty list () is the same as an empty literal "".

Escape character \, used in literals to represent " or $ or \.
literal="1 2 3 \${list1} 4 5" is substituted to "1 2 3 ${list1} 4 5".
*/

create or replace function head
(   in  list item_type[]
,   out head item_type[]
)
as
$$
declare
    l    integer := 0;
    item item_type;
begin
    head := array[]::item_type[];
    foreach item in array list
    loop
        if item.parenthesis
        then
            case item.literal
            when '(' then if l > 0 then head := head || item; end if; l := l + 1;
            when ')' then l := l - 1; if l > 0 then head := head || item; end if;
            else null;
            end case;
        else
            head := head || item;
        end if;
        exit when l = 0;
    end loop
    ;
end
$$ language plpgsql
;

create or replace function tail
(   in  list item_type[]
,   out tail item_type[]
)
as $$
declare
    l            integer := 0;
    item         item_type;
    head_skipped boolean := false;
begin
    tail := array[]::item_type[];
    foreach item in array list
    loop
        if head_skipped then
            tail := tail || item;
        else
            if item.parenthesis
            then
                case item.literal
                when '(' then l := l + 1;
                when ')' then l := l - 1;
                else null;
                end case;
            end if;
            if l = 0 then
                head_skipped := true;
            end if;
        end if;
    end loop
    ;
end
$$ language plpgsql
;

/*
Substituce--pravidla:
Pokud substituuji hodnotu proměnné y za podřetězec ${y} hodnoty proměnné z, pak hodnota y nesmí obsahovat žádnou proměnnou ${z}.

NELZE:
y='aaa${z}bb'
x='123-${y}-XYZ'
TAKHLE NE!
MISTO TOHO REKNU PORADI SUBSTITUCI A NEKTERE PROMENE HOLT ZUSTANOU NENAHRAZENE HODNOTOU

Potřebuji substituce
v textu--CALLS
v hodnotě--IDENTIFIERS
ve vlastnosti--FEATURES
 */

create or replace function project
(   in  items  item_type[]
,   out result text
)
as $$
declare
    item item_type;
begin
    if items is null
    then
        result := null::text;
    elseif array_length(items, 1) = 1
    then
        result := (items[1]).literal;
    else
        result := '(';
        foreach item in array items
        loop
            result := result || ' ' || item.literal;
        end loop;
        result := result || ' )';
    end if;
end
$$ language plpgsql
;
/*
postgres=>
select
    project
    (   array
        [   row('(',null)
        ,   row(null,'prd')
        ,   row(null,'el')
        ,   row(')',null)
        ]::item_type[]
    )
;
 project 
---------
 prdel
(1 row)

postgres=>
select
    project
    (   array
        [   row(null,'prd')
        ]::item_type[]
    )
;
 project 
---------
 prd
(1 row)

postgres=> 
*/

create or replace function project
(   in  values_ value_type[]
,   out result  text[]
)
as $$
declare
    value value_type;
begin
    if values_ is null
    then
        result := null::text[];
    else
        result := array[]::text[];
        foreach value in array values_
        loop
            result := result || project(value.items);
        end loop;
    end if;
end
$$ language plpgsql
;

create or replace function project
(   in  features feature_type[]
,   out result   variable_type[]
)
as $$
declare
    feature feature_type;
begin
    if features is null
    then
        result := null::variable_type[];
    else
        result := array[]::variable_type[];
        foreach feature in array features
        loop
            result := result || row(feature.name, project((feature.value).items))::variable_type;
        end loop;
    end if;
end
$$ language plpgsql
;


create or replace function evaluate
(   in  literal  text
,   in  features feature_type[]
,   out result   text
)
immutable
as $$
declare
    feature feature_type;
    item    item_type;
    x       record;
begin
    result := '';
    for x in select string_to_array(unnest(string_to_array('${}' || literal, '${')), '}') as dbl
    loop
        foreach feature in array features
        loop
            if (x.dbl)[1] = (feature).name
            then
                result := result || project(((feature).value).items);
            end if;
        end loop;
        if (x.dbl)[2] is not null
        then
            result := result || (x.dbl)[2];
        end if;
    end loop;
end
$$ language plpgsql
;
/*
postgres=>
select
    evaluate
    (   'aaa${hovno}123'
    ,   array
        [   row
            (   'hovno'
            ,   row
                (   null
                ,   array
                    [   row('(',null)
                    ,   row(null,'prd')
                    ,   row(null,'el')
                    ,   row(')',null)
                    ]::item_type[]
                )
            )
        ]::feature_type[]
    )
;
 evaluate  
-------------
 aaaprdel123
(1 row)

postgres=> 
*/


create or replace function evaluate
(   in  item     item_type
,   in  features feature_type[]
,   out result   item_type[]
)
immutable
as $$
declare
    feature feature_type;
begin
    if item.parenthesis then
        result := array[item]::item_type[];
    else
        foreach feature in array features
        loop
            if item.literal = '${'||feature.name||'}' then
                result := (feature.value).items;
                return;
            end if;
        end loop;
        result := array[row(null, evaluate(item.literal, features))]::item_type[];
    end if;
end
$$ language plpgsql
;
/*
postgres=>
select
    evaluate
    (   row(null,'aaa${hovno}123')::item_type
    ,   array
        [   row
            (   'hovno'
            ,   row
                (   null
                ,   array
                    [   row('(',null)
                    ,   row(null,'prd')
                    ,   row(null,'el')
                    ,   row(')',null)
                    ]::item_type[]
                )
            )
        ]::feature_type[]
    )
;
     evaluate     
--------------------
 {"(,aaaprdel123)"}
(1 row)

postgres=> 
postgres=>
select
    evaluate
    (   row(null,'${hovno}')::item_type
    ,   array
        [   row
            (   'hovno'
            ,   row
                (   null
                ,   array
                    [   row('(',null)
                    ,   row(null,'prd')
                    ,   row(null,'el')
                    ,   row(')',null)
                    ]::item_type[]
                )
            )
        ]::feature_type[]
    )
;
                evaluate                
------------------------------------------
 {"(\"(\",)","(,prd)","(,el)","(\")\",)"}
(1 row)

postgres=> 
*/


create or replace function evaluate
(   in  value    value_type
,   in  features feature_type[]
,   out result   value_type
)
immutable
as $$
declare
    item     item_type;
    operator operator_type;
begin
    result := row(null,array[]::item_type[])::value_type;
    foreach item in array value.items
    loop
        result.items := result.items || evaluate(item, features);
    end loop;
    foreach operator in array value.operators
    loop
        case operator
        when 'head' then result.items := head(result.items);
        when 'tail' then result.items := tail(result.items);
        else null;
        end case;
    end loop;
end
$$ language plpgsql
;
/*
select
    evaluate
    (   row
        (   array['head']::operator_type[]
        ,   array
            [   row(null, '${x}')
            ]::item_type[]
        )::value_type
    ,   array
        [   row('x',row(array[]::operator_type[],array[row(null,'1'),row(null,'2')]::item_type[]))
        ]::feature_type[]
    )
;
select
    evaluate
    (   row
        (   array['head']::operator_type[]
        ,   array
            [   row(null, '${x}')
            ]::item_type[]
        )::value_type
    ,   array
        [   row('x',row(null::operator_type[],array[row(null,'1'),row(null,'2')]::item_type[]))
        ]::feature_type[]
    )
;
select
    evaluate
    (   row
        (   array['tail']::operator_type[]
        ,   array
            [   row(null, '${x}')
            ]::item_type[]
        )::value_type
    ,   array
        [   row('x',row(array[]::operator_type[],array[row(null,'1'),row(null,'2')]::item_type[]))
        ]::feature_type[]
    )
;
select
    evaluate
    (   row
        (   array['tail']::operator_type[]
        ,   array
            [   row(null, '${x}')
            ]::item_type[]
        )::value_type
    ,   array
        [   row('x',row(null::operator_type[],array[row(null,'1'),row(null,'2')]::item_type[]))
        ]::feature_type[]
    )
;
select
    evaluate
    (   row
        (   array['head','tail']::operator_type[]
        ,   array
            [   row(null, '${x}')
            ]::item_type[]
        )::value_type
    ,   array
        [   row('x',row(null::operator_type[],array[row(null,'1'),row(null,'2')]::item_type[]))
        ]::feature_type[]
    )
;
select
    evaluate
    (   row
        (   array['tail','tail']::operator_type[]
        ,   array
            [   row(null, '${x}')
            ]::item_type[]
        )::value_type
    ,   array
        [   row('x',row(null::operator_type[],array[row(null,'1'),row(null,'2')]::item_type[]))
        ]::feature_type[]
    )
;
select
    evaluate
    (   row
        (   array['tail','head']::operator_type[]
        ,   array
            [   row(null, '${x}')
            ]::item_type[]
        )::value_type
    ,   array
        [   row('x',row(null::operator_type[],array[row(null,'1'),row(null,'2')]::item_type[]))
        ]::feature_type[]
    )
;
select
    evaluate
    (   row
        (   array['head','head']::operator_type[]
        ,   array
            [   row(null, '${x}')
            ]::item_type[]
        )::value_type
    ,   array
        [   row('x',row(null::operator_type[],array[row(null,'1'),row(null,'2')]::item_type[]))
        ]::feature_type[]
    )
;

 */

create or replace function evaluate
(   in  values_   value_type[]
,   in  features feature_type[]
,   out result   value_type[]
)
immutable
as $$
declare
    value value_type;
begin
    result := array[]::value_type[];
    foreach value in array values_
    loop
        result := result || evaluate(value, features);
    end loop;
end
$$ language plpgsql
;


create or replace function evaluate
(   in  feature  feature_type
,   in  features feature_type[]
,   out result   feature_type
)
immutable
as $$
begin
    result := row(feature.name, evaluate(feature.value, features))::feature_type;
end
$$ language plpgsql
;

/*
select
    evaluate
    (   row
        (   'x'
        ,   row
            (   array['tail']::operator_type[]
            ,   array[row(null,'${y}')]::item_type[]
            )
        )::feature_type
    ,   array
        [   row
            (   'y'
            ,   row
                (   array['tail']::operator_type[]
                ,   array[row('(',null),row(null,'A'),row(null,'A'),row(null,'A'),row(')',null),row('(',null),row(null,'A'),row(null,'A'),row(null,'A'),row(')',null)]::item_type[]
                )
            )
        ]::feature_type[]
    )
;
 */

create or replace function evaluate
(   in  features1 feature_type[]
,   in  features2 feature_type[]
,   out result    feature_type[]
)
immutable
as $$
declare
    feature feature_type;
begin
    result := array[]::feature_type[];
    if features1 is not null
    then
        foreach feature in array features1
        loop
            result := result || evaluate(feature, features2);
        end loop;
    end if;
end
$$ language plpgsql
;

create or replace function parameters_to_features
(   in  names   text[]
,   in  values_ value_type[]
,   out result  feature_type[]
)
immutable
as $$
declare
    name text;
    i    integer := 0;
begin
    result := array[]::feature_type[];
    if names is not null
    then
        foreach name in array names
        loop
            i := i + 1;
            result := result || row(name, values_[i])::feature_type;
        end loop;
    end if;
end
$$ language plpgsql
;

/*
create or replace function array_all_but_last
(   in  array_ anyarray
,   out result anyarray
)
immutable
as $$
begin
    result := array_[1 : array_length(array_, 1) - 1];
end
$$ language plpgsql
;

create or replace function array_last
(   in  array_ anyarray
,   out result anyelement
)
immutable
as $$
begin
    result := array_[array_length(array_, 1)];
end
$$ language plpgsql
;
*/

create or replace function merge_features
(   in  features1 feature_type[]
,   in  features2 feature_type[]
,   out result    feature_type[]
)
immutable
as $$
begin
    result :=
        array
        (   select
                row(coalesce(f1.name, f2.name), coalesce(f1.value, f2.value))::feature_type
            from            unnest(features1) as f1
            full outer join unnest(features2) as f2
            on f1.name = f2.name
        )
    ;    
end
$$ language plpgsql
;

/*
create or replace function identifier_value
(   in  identifiers value_type[]
,   out result      text
)
immutable
as $$
begin
    result := '';
    if i_identifier is null
    then
        return r;
    end if;
    for i in 1 .. coalesce(array_length(i_identifier, 1), 0)
    loop
        r := r || ' "' || (i_identifier[i]).value || '"';
    end loop;
    return r;
end
$$ language plpgsql
;
*/

create or replace function empty_list
(   in values_  value_type[]
,   in features feature_type[]
,   out result  boolean
)
immutable
as $$
declare
    v     value_type;
    value value_type;
begin
    result := false;
    if values_ is not null
    then
        foreach value in array values_
        loop
            if value.operators = array['tail']::operator_type[]
            then
                v := evaluate(value, features);
                if v.items = array[]::item_type[]
                then
                    result := true;
                    return;
                end if;
            end if;
        end loop;
    end if;
end
$$ language plpgsql
;

create or replace function evaluate
(   in  task_identifiers text[]
,   in  call_identifiers value_type[]
,   in  call_features    feature_type[]
,   in  task_features    feature_type[]
,   in  features         feature_type[]
,   out result           feature_type[]
)
as $$
declare
    feature feature_type;
begin
    result
    :=  merge_features
        (   evaluate
            (   merge_features
                (   parameters_to_features
                    (   task_identifiers
                    ,   call_identifiers
                    )
                ,   call_features
                )
            ,   features
            )
        ,   features
        )
    ;
    if task_features is not null
    then
        foreach feature in array task_features
        loop
            result
            :=  merge_features
                (   evaluate
                    (   array[feature]::feature_type[]
                    ,   result
                    )
                ,   result
                )
            ;
        end loop;
    end if;
end
$$ language plpgsql
;

create or replace function to_char
(   in  text[]
,   out text
)
as $$
declare
    t text;
begin
    $2 := '';
    if $1 is not null
    then
        foreach t in array $1
        loop
            $2 := $2 || ' ' || t;
        end loop;
    end if;
end
$$ language plpgsql
;

create or replace view instance_evaluations
as
(
select
    coalesce(lpad('', array_length(x.instance_node_id, 1) * 2), '')
    ||  coalesce(x.execution::text, '')
    ||  coalesce(' ' || i.task_name, '')
    ||  coalesce(to_char(i.identifiers), '')
,   l.log_type as evaluation_type
,   l.message as evaluation_message
from instance_nodes as x
left outer join instances as i on i.instance_id = x.instance_id
left outer join evaluations as l on l.instance_id = x.instance_id
order by x.instance_node_id
)
;

create or replace function evaluate () returns setof instance_evaluations
as $$
begin
    create temporary table evaluated_calls
    as
    (
    with
        recursive x
        (   task_id
        ,   task_name
        ,   identifiers
        ,   features
        ,   call_id
        ,   dep_task_name
        ,   dep_identifiers
        ,   call_root_id
        ,   call_leaf_id
        ,   condition_root_id
        )   
        as
        (
        select
            task_id
        ,   task_name
        ,   array[]::value_type[]
        ,   features
        ,   null::integer
        ,   null::text
        ,   array[]::value_type[]
        ,   call_root_id
        ,   null::integer
        ,   null::integer
        from tasks
        where task_name = 'main'
        union all 
        select
            t.task_id
        ,   evaluate(c.call_name,  x.features)
        ,   evaluate(c.identifiers, x.features)
        ,   evaluate(t.identifiers, c.identifiers, c.features, t.features, x.features)
        ,   c.call_id
        ,   x.task_name
        ,   x.identifiers
        ,   t.call_root_id
        ,   l.call_leaf_id
        ,   l.condition_root_id
        from x
        inner join call_leaves as l on l.dependent_task_id = x.task_id
        inner join calls as c on c.call_id = l.call_id
        left outer join tasks as t on t.task_name = evaluate(c.call_name, x.features)
        where not empty_list(c.identifiers, x.features)
        )
    select
        task_id
    ,   task_name
    ,   project(identifiers) as projected_identifiers
    ,   project(features) as projected_features
    ,   features
    ,   call_id
    ,   dep_task_name
    ,   project(dep_identifiers) as projected_dep_identifiers
    ,   call_root_id
    ,   call_leaf_id
    ,   condition_root_id
    from x
    )
    ;
    
    create temporary table evaluated_conditions
    as
    (
    select
        l.condition_leaf_id
    ,   evaluate(c.call_name, e.features) as task_name
    ,   project(evaluate(c.identifiers, e.features)) as projected_identifiers
    ,   e.task_name as dep_task_name
    ,   e.projected_identifiers as projected_dep_identifiers
    ,   l.status
    from evaluated_calls as e
    inner join condition_leaves as l on l.dependent_call_id = e.call_id
    inner join calls as c on c.call_id = l.call_id
    )
    ;

    update instances
    set active =
        (   (task_name, identifiers) in
            (   select task_name, projected_identifiers from evaluated_calls
                union
                select task_name, projected_identifiers from evaluated_conditions
            )
        )
    ;
    
    insert into instances
    (   task_name
    ,   identifiers
    ,   active
    )
    select
        task_name
    ,   projected_identifiers
    ,   true
    from
    (   select task_name, projected_identifiers from evaluated_calls
        union
        select task_name, projected_identifiers from evaluated_conditions
    ) as t
    where (task_name, projected_identifiers) not in (select task_name, identifiers from instances)
    ;
    
    insert into instance_relations
    (   instance_id
    ,   dependent_instance_id
    ,   call_root_id
    ,   call_leaf_id
    ,   condition_root_id
    )
    select
        i.instance_id
    ,   d.instance_id
    ,   y.call_root_id
    ,   y.call_leaf_id
    ,   y.condition_root_id
    from evaluated_calls as y
    inner join instances as i on i.task_name = y.task_name and i.identifiers = y.projected_identifiers
    left outer join instances as d on d.task_name = y.dep_task_name and d.identifiers = y.projected_dep_identifiers
    ;
    
    insert into instance_features
    (   instance_id
    ,   features
    )
    select
        i.instance_id
    ,   y.projected_features
    from evaluated_calls as y
    inner join instances as i on i.task_name = y.task_name and i.identifiers = y.projected_identifiers
    where i.instance_id not in (select distinct dependent_instance_id from instance_relations where dependent_instance_id is not null)
    ;

    insert into instance_condition_leaves
    (   condition_leaf_id
    ,   dependent_instance_id
    ,   instance_id
    ,   status
    )
    select e.condition_leaf_id, d.instance_id, i.instance_id, e.status
    from evaluated_conditions as e
    inner join instances as i on i.task_name = e.task_name and i.identifiers = e.projected_identifiers
    inner join instances as d on d.task_name = e.dep_task_name and d.identifiers = e.projected_dep_identifiers
    ;

    insert into instance_scripts
    (   instance_id
    ,   script_type
    ,   script
    )
    select i.instance_id, 'execute'::script_type, evaluate(t.exe_script, e.features)
    from evaluated_calls as e
    inner join tasks     as t on t.task_id = e.task_id
    inner join instances as i on i.task_name = e.task_name and i.identifiers = e.projected_identifiers
    where t.exe_script is not null
    union all
    select i.instance_id, 'generate'::script_type, evaluate(t.gen_script, e.features)
    from evaluated_calls as e
    inner join tasks as t on t.task_id = e.task_id
    inner join instances as i on i.task_name = e.task_name and i.identifiers = e.projected_identifiers
    where t.gen_script is not null
    ;

    insert into evaluations
    (   instance_id
    ,   log_type
    ,   message
    )
    select
        instance_id
    ,   'error'
    ,   'Task does not exist.'
    from instances
    where active and task_name not in (select task_name from tasks)
    ;
    
    insert into evaluations
    (   instance_id
    ,   log_type
    ,   message
    )
    select
        instance_id
    ,   'warning'
    ,   'Incorrect number of identifiers.'
    from instances as i
    inner join tasks as t on t.task_name = i.task_name
    where i.active and array_length(i.identifiers, 1) <> array_length(t.identifiers, 1)
    ;
    with recursive
        y (instance_id, instance_node_id, call_node_id, execution, leaf_instance_id)
        as
        (
            select
                r.instance_id
            ,   array[n.position]::integer[]
            ,   n.call_node_id
            ,   n.execution
            ,   rr.instance_id
            from call_nodes as n
            inner join instance_relations as r
                on  r.call_root_id = n.call_node_id
            left outer join instance_relations as rr
                on  rr.call_leaf_id = n.call_node_id
                and rr.dependent_instance_id = r.instance_id
            where n.parent_call_node_id is null
        union all
            select
                y.instance_id
            ,   y.instance_node_id || n.position
            ,   n.call_node_id
            ,   n.execution
            ,   rr.instance_id
            from y
            inner join call_nodes as n
                on  n.parent_call_node_id = y.call_node_id
            left outer join instance_relations as rr
                on  rr.call_leaf_id = n.call_node_id
                and rr.dependent_instance_id = y.instance_id
        )
    ,   x (instance_node_id, execution, instance_id)
        as
        (
            select
                array[]::integer[]
            ,   'call'::execution_type
            ,   instance_id
            from instances
            where task_name = 'main' and identifiers = array[]::text[]
        union all 
            select
                x.instance_node_id || c.instance_node_id
            ,   c.execution
            ,   c.leaf_instance_id
            from x
            left outer join y as c on c.instance_id = x.instance_id
            where x.execution <> 'call' or c.instance_id is not null
        )
    insert into instance_nodes
    (   instance_node_id
    ,   execution
    ,   instance_id
    ,   parent_instance_node_id
    ,   position
    )
    select
        instance_node_id
    ,   execution
    ,   instance_id
    ,   instance_node_id[1:array_length(instance_node_id, 1) - 1] as parent_instance_node_id
    ,   instance_node_id[array_length(instance_node_id, 1)] as position
    from x
    where execution is not null and not (execution = 'call'::execution_type and instance_id is null)
    ;
    return query (select * from instance_evaluations);
end
$$ language plpgsql
;

\q

with recursive
    x (dep_instance_id, instance_node_id, parent_instance_node_id, position, execution, result) as
    (
        select
            n.instance_id
        ,   n.instance_node_id
        ,   n.parent_instance_node_id
        ,   n.position
        ,   n.execution
        ,   null::integer[]
        from instance_nodes as n
        left outer join instance_nodes as r
            on  r.parent_instance_node_id = n.instance_node_id
        where r.instance_node_id is null
    union all
        select
            x.dep_instance_id
        ,   p.instance_node_id
        ,   p.parent_instance_node_id
        ,   p.position
        ,   x.execution
        ,   case
            when p.execution = 'in sequence' and x.position > 0
            then x.instance_node_id[1 : array_length(x.instance_node_id, 1) - 1] || (x.position - 1)
            end
        from x
        inner join instance_nodes as p on p.instance_node_id = x.parent_instance_node_id
        where x.result is null
    )
--select dep_instance_id, result as instance_node_id
--from x
--where result is not null
--;
--
--with recursive
,   y (dep_instance_id, execution, instance_node_id, instance_id) as 
    (
        select
            dep_instance_id
        ,   execution
        ,   result
        ,   null::integer
        from x
    union all
        select
            y.dep_instance_id
        ,   c.execution
        ,   c.instance_node_id
        ,   case when not exists (select null from instance_nodes where parent_instance_node_id = c.instance_node_id) then c.instance_id end
        from y
        inner join instance_nodes as c
            on  c.parent_instance_node_id = y.instance_node_id
            and (   y.execution <> 'in sequence'
                or  (   y.execution = 'in sequence'
                    and c.instance_node_id = (select max(instance_node_id) from instance_nodes where parent_instance_node_id = y.instance_node_id)
                    )
                )
        where y.instance_id is null
    )
select
    y.dep_instance_id
,   d.task_name as dep_task_name
,   d.identifiers as dep_identifiers
,   y.instance_id
,   i.task_name
,   i.identifiers
from y
inner join instances as d on d.instance_id = y.dep_instance_id
inner join instances as i on i.instance_id = y.instance_id
where y.instance_id is not null
order by y.dep_instance_id, y.instance_id
;

\q

with recursive x as (

select
    r.instance_id
,   r.dependent_instance_id
,   n.parent_call_node_id
,   n.position
,   false as done
,   null::integer as call_node_id
from instance_relations as r
inner join call_nodes as n on n.call_node_id = r.call_leaf_id
where not exists (select null from instance_relations where dependent_instance_id = r.instance_id)

union all

select
    x.instance_id
,   coalesce(r.dependent_instance_id, x.dependent_instance_id)
,   coalesce(p.parent_call_node_id, n.parent_call_node_id)
,   coalesce(p.position, n.position)
,   s.call_node_id is not null or r.dependent_instance_id is null
,   s.call_node_id
from x
left outer join call_nodes         as p on p.call_node_id = x.parent_call_node_id
left outer join call_nodes         as s on s.parent_call_node_id = x.parent_call_node_id and s.position + 1 = x.position and p.execution = 'in sequence'
left outer join instance_relations as r on r.instance_id = x.dependent_instance_id and x.parent_call_node_id is null-- zde upravit, aby to fungovalo i pro task main
left outer join call_nodes         as n on n.call_node_id = r.call_leaf_id
where not x.done

)
select instance_id, dependent_instance_id, call_node_id
from x
where call_node_id is not null
order by dependent_instance_id, call_node_id
;

with recursive x as (

select
    r.instance_id
,   r.dependent_instance_id
,   n.parent_call_node_id
,   n.position
,   false as done
,   null::integer as call_node_id
from instance_relations as r
inner join call_nodes as n on n.call_node_id = r.call_leaf_id
where not exists (select null from instance_relations where dependent_instance_id = r.instance_id)

union all

select
    x.instance_id
,   coalesce(r.dependent_instance_id, x.dependent_instance_id)
,   coalesce(p.parent_call_node_id, n.parent_call_node_id)
,   coalesce(p.position, n.position)
,   s.call_node_id is not null-- or r.dependent_instance_id is null
,   s.call_node_id
from x
left outer join call_nodes         as p on p.call_node_id = x.parent_call_node_id
left outer join call_nodes         as s on s.parent_call_node_id = x.parent_call_node_id and s.position + 1 = x.position and p.execution = 'in sequence'
left outer join instance_relations as r on r.instance_id = x.dependent_instance_id and x.parent_call_node_id is null
left outer join call_nodes         as n on n.call_node_id = r.call_leaf_id and x.parent_call_node_id is null
where x.call_node_id is null and (r.instance_id is not null and n.call_node_id is not null or p.call_node_id is not null)

)
select instance_id, dependent_instance_id, call_node_id
from x
where call_node_id is not null
order by dependent_instance_id, call_node_id
;

select
    n.call_node_id
,   n.parent_call_node_id
,   n.position
,   ir.instance_id as root_instance_id
,   rr.dependent_instance_id
,   il.instance_id as leaf_instance_id
,   rl.dependent_instance_id
from call_nodes as n
left outer join instance_relations as rr on rr.call_root_id = n.call_node_id
left outer join instance_relations as rl on rl.call_leaf_id = n.call_node_id
left outer join instances as ir on ir.instance_id = rr.instance_id
left outer join instances as il on il.instance_id = rl.instance_id
;

with recursive x as (

select
    array[n.position]::integer[] as call_node_path
,   i.instance_id
,   i.task_name
,   i.identifiers
,   n.call_node_id
,   n.execution
,   ii.instance_id as called_instance_id
,   ii.task_name as called_task_name
,   ii.identifiers as called_identifiers
from instance_relations as r
inner join instances as i on i.instance_id = r.instance_id
left outer join call_nodes as n on n.call_node_id = r.call_root_id
left outer join instance_relations as rr on rr.dependent_instance_id = r.instance_id and rr.call_leaf_id = n.call_node_id
left outer join instances as ii on ii.instance_id = rr.instance_id
--where i.active-- and i.task_name = 'main'

union all

select
    x.call_node_path || n.position
,   x.instance_id
,   x.task_name
,   x.identifiers
,   n.call_node_id
,   n.execution
,   ii.instance_id
,   ii.task_name
,   ii.identifiers
from x
inner join call_nodes as n on n.parent_call_node_id = x.call_node_id
left outer join instance_relations as rr on rr.dependent_instance_id = x.instance_id and rr.call_leaf_id = x.call_node_id
left outer join instances as ii on ii.instance_id = rr.instance_id
)

select * from x order by 2, 1
;

with recursive x (instance_id_path, instance_id, task_name, identifiers) as
(

select
    array[i.instance_id]::integer[]
,   i.instance_id
,   i.task_name
,   i.identifiers
from instance_relations as r
inner join instances as i on i.instance_id = r.instance_id
where r.dependent_instance_id is null

union all 

select
    x.instance_id_path || i.instance_id
,   i.instance_id
,   i.task_name
,   i.identifiers
from x
inner join instance_relations as r on x.instance_id = r.dependent_instance_id
inner join instances as i on i.instance_id = r.instance_id

)

select *
from x
order by 1
;

\q

create or replace view evaluated_calls as

with recursive x
    (   cal_tree_path
    ,   cal_id
    ,   cal_order
    ,   tsk_id
    ,   tsk_id_child
    ,   cal_type
    ,   tsk_type
    ,   cal_name
    ,   cal_identifier
    ,   cal_feature
    ,   counter
    )
as (

    select
        ARRAY[]::integer[]       as cal_tree_path
    ,   null::integer            as cal_id
    ,   null::integer            as cal_order
    ,   null::integer            as tsk_id
    ,   tsk_id                   as tsk_id_child
    ,   'IN PARALLEL'::call_type as cal_type
    ,   tsk_type                 as tsk_type
    ,   tsk_name                 as cal_name
    ,   ARRAY[]::value_type[]    as cal_identifier
    ,   tsk_feature              as cal_feature
    ,   0                        as counter
    
    from tasks

    where lower(tsk_name) = 'main'

    union all

    select  x.cal_tree_path || c.cal_order
        ,   c.cal_id
        ,   c.cal_order
        ,   c.tsk_id
        ,   t.tsk_id
        ,   case t.tsk_type
                when 'CALL'        then 'IN PARALLEL'::call_type
                when 'EXECUTE'     then 'TASK'::call_type
                when 'GENERATE'    then 'TASK'::call_type
                else c.cal_type
            end
        ,   t.tsk_type
        ,   evaluate(c.cal_name,       x.cal_feature)
        ,   evaluate(c.cal_identifier, x.cal_feature)
        ,   merge_features
            (   evaluate
                (   t.tsk_feature
                ,   merge_features
                    (   evaluate
                        (   merge_features
                            (   c.cal_feature
                            ,   parameters_to_features(t.tsk_identifier, c.cal_identifier)
                            )
                        ,   x.cal_feature
                        )
                    ,   x.cal_feature
                    )
                )
            ,   merge_features
                (   evaluate
                    (   merge_features
                        (   c.cal_feature
                        ,   parameters_to_features(t.tsk_identifier, c.cal_identifier)
                        )
                    ,   x.cal_feature
                    )
                ,   x.cal_feature
                )
            )
        ,   x.counter + 1
    from x

    inner join calls as c
    on  (   c.tsk_id = x.tsk_id
        and c.cal_id_parent = x.cal_id
        )
    or  (   c.tsk_id = x.tsk_id_child
        and c.cal_id_parent is null
        )
    
    left outer join tasks as t
    on lower(t.tsk_name) = lower(evaluate(c.cal_name, x.cal_feature))

    where not empty_list(c.cal_identifier, x.cal_feature)
)

select
    x.cal_tree_path
,   x.cal_order
,   x.cal_id
,   x.tsk_id_child as tsk_id
,   x.cal_type
,   x.tsk_type
,   x.cal_name
,   x.cal_identifier[1 : array_length(t.tsk_identifier, 1)] as cal_identifier
,   x.cal_feature

from x

left outer join tasks as t
on t.tsk_id = x.tsk_id_child
;

create or replace view evaluated_conditions as

with recursive x
    (   calins_id
    ,   cal_id
    ,   con_id
    ,   con_tree_path
    ,   con_connective
    ,   cal_name
    ,   cal_identifier
    ,   run_status
    ,   cal_feature
    )
as (
    select  ci.calins_id
        ,   ci.cal_id
        ,   c.con_id
        ,   ARRAY[]::integer[]
        ,   c.con_connective
        ,   evaluate(c.cal_name,       ci.cal_feature)
        ,   evaluate(c.cal_identifier, ci.cal_feature)
        ,   c.run_status
        ,   ci.cal_feature
    from call_instances as ci
    join conditions     as c  on c.cal_id = ci.cal_id
    where c.con_id_parent is null
    --
    union all
    --
    select  x.calins_id
        ,   x.cal_id
        ,   c.con_id
        ,   x.con_tree_path || c.con_order
        ,   c.con_connective
        ,   evaluate(c.cal_name,       x.cal_feature)
        ,   evaluate(c.cal_identifier, x.cal_feature)
        ,   c.run_status
        ,   x.cal_feature
    from x
    join conditions as c on c.con_id_parent = x.con_id
)
select  x.calins_id
    ,   x.con_tree_path
    ,   x.con_connective
    ,   c.calins_id as calins_id_con
    ,   x.cal_name
    ,   x.cal_identifier
    ,   x.run_status
from x
left join call_instances as c
    on c.cal_name = x.cal_name
    and (   c.cal_identifier = x.cal_identifier
        or  (   c.cal_identifier is null
            and x.cal_identifier is null
            )
        )
;

create or replace view call_deps_1 as
with recursive x
    (   calins_id
    ,   cal_tree_path
    ,   cal_tree_path_x
    )
as (
    select calins_id, cal_tree_path, cal_tree_path
    from call_instances
    where cal_type in ('TASK', 'RESTART')
    --
    union all
    --
    select x.calins_id, x.cal_tree_path, c.cal_tree_path
    from x
    join call_instances as c
        on c.cal_tree_path = array_all_but_last(x.cal_tree_path_x)
    where  c.cal_tree_path <> ARRAY[]::integer[]
        and
        (   c.cal_type = 'IN PARALLEL'
        or  c.cal_type = 'IN SEQUENCE' and array_last(x.cal_tree_path_x) = 1
        )
)
select  calins_id
    ,   cal_tree_path
    ,   array_all_but_last(cal_tree_path_x)
        || (array_last(cal_tree_path_x) - 1) as cal_tree_path_x
from
    (
    select  calins_id, cal_tree_path, cal_tree_path_x
        ,   row_number() over (partition by cal_tree_path order by array_length(cal_tree_path_x, 1) nulls first) as rn
    from x
    ) as t
where rn = 1 and cal_tree_path_x <> ARRAY[1]::integer[]
;

create or replace view call_deps_2 as
with recursive x
    (   cal_tree_path_x
    ,   calins_id
    ,   cal_type
    ,   cal_tree_path
    ,   tsk_type)
as (
    select  cal_tree_path
        ,   calins_id
        ,   cal_type
        ,   cal_tree_path
        ,   tsk_type
    from call_instances
    where cal_tree_path <> ARRAY[]::integer[]
    --
    union all
    --
    select  x.cal_tree_path_x
        ,   c.calins_id
        ,   c.cal_type
        ,   c.cal_tree_path
        ,   c.tsk_type
    from x
    join call_instances as c
        on x.cal_tree_path = array_all_but_last(c.cal_tree_path)
    where   x.tsk_type is null
        and (   x.cal_type = 'IN PARALLEL'
            or  (   x.cal_type = 'IN SEQUENCE'
                and array_last(c.cal_tree_path) = (
                    select max(array_last(z.cal_tree_path))
                    from call_instances as z
                    where x.cal_tree_path = array_all_but_last(z.cal_tree_path)
                    )
                )
            )
)
select distinct cal_tree_path_x
    ,   calins_id
    ,   cal_tree_path
from x
where tsk_type is not null
;

create or replace view call_tree as
select  calins_id
    ,   cal_tree_path
    ,   cal_id
    ,   tsk_id
    ,   coalesce(lpad('', 2 * array_length(cal_tree_path, 1)), '') -- indentation
        ||  case tsk_type
            when 'CALL' then ''
            else
                case cal_type
                when 'TASK' then ''
                else cal_type::text
                end -- in parallel / in sequence / restart
            end
        ||  case
            when cal_name = 'RESTART' or tsk_type is null then ''
            else '' || tsk_type || ' ' || cal_name || identifier_value(cal_identifier)
            end as task_call
    /*
    ,   coalesce(lpad('', 2 * array_length(cal_tree_path, 1)), '') -- indentation
        ||  case cal_type when 'TASK' then '' else cal_type::text end -- in parallel / in sequence / restart
        ||  case
                when cal_name = 'RESTART' or tsk_type is null then ''
                else ''
                    ||  case tsk_type when 'CALL' then ' -- ' else '' end
                    ||  tsk_type
                    ||  ' '
                    ||  cal_name
                    ||  identifier_value(cal_identifier)
            end as task_call
    */
from call_instances
order by cal_tree_path
;

create or replace view call_dependences as
select  x.calins_id
    ,   x.cal_tree_path
    ,   y.calins_id as calins_id_x
    ,   y.cal_tree_path as cal_tree_path_x
from call_deps_1 as x
join call_deps_2 as y
    on  x.cal_tree_path_x = y.cal_tree_path_x
;

create or replace view call_tree as
select  calins_id
    ,   cal_tree_path
    ,   cal_id
    ,   tsk_id
    ,   coalesce(lpad('', 2 * array_length(cal_tree_path, 1)), '') -- indentation
        ||  case tsk_type
            when 'CALL' then ''
            else
                case cal_type
                when 'TASK' then ''
                else cal_type::text
                end -- in parallel / in sequence / restart
            end
        ||  case
            when cal_name = 'RESTART' or tsk_type is null then ''
            else '' || tsk_type || ' ' || cal_name || identifier_value(cal_identifier)
            end as task_call
    /*
    ,   coalesce(lpad('', 2 * array_length(cal_tree_path, 1)), '') -- indentation
        ||  case cal_type when 'TASK' then '' else cal_type::text end -- in parallel / in sequence / restart
        ||  case
                when cal_name = 'RESTART' or tsk_type is null then ''
                else ''
                    ||  case tsk_type when 'CALL' then ' -- ' else '' end
                    ||  tsk_type
                    ||  ' '
                    ||  cal_name
                    ||  identifier_value(cal_identifier)
            end as task_call
    */
from call_instances
order by cal_tree_path
;

create or replace view condition_tree as
select  calins_id
    ,   con_tree_path
    ,   calins_id_con
    ,   lpad('', 2 * coalesce(array_length(con_tree_path, 1), 0))
        ||  coalesce(con_connective::text, '')
        ||  coalesce(
                case cal_name
                    when 'RESTART'
                    then cal_name
                    else cal_name
                        ||  identifier_value(cal_identifier) || ' '
                        ||  run_status::text
                end
                , '') as condition
from condition_instances
order by calins_id, con_tree_path
;

/******************************************************************************/
/* Call / Condition Instances Functions                                       */
/******************************************************************************/

--delete from condition_instances ;
--delete from call_instances ;

create or replace function create_call_instances ()
    returns integer
    volatile
as $$
    begin
        insert into call_instances
            (   cal_tree_path
            ,   tsk_id
            ,   cal_id
            ,   cal_type
            ,   tsk_type
            ,   cal_name
            ,   cal_identifier
            ,   cal_feature
            )
        select  cal_tree_path
            ,   tsk_id
            ,   cal_id
            ,   cal_type
            ,   tsk_type
            ,   cal_name
            ,   cal_identifier
            ,   cal_feature
        from evaluated_calls
        order by cal_tree_path
        ;
        insert into condition_instances
            (   calins_id
            ,   con_tree_path
            ,   con_connective
            ,   calins_id_con
            ,   cal_name
            ,   cal_identifier
            ,   run_status
            )
        select  calins_id
            ,   con_tree_path
            ,   con_connective
            ,   calins_id_con
            ,   cal_name
            ,   cal_identifier
            ,   run_status
        from evaluated_conditions
        order by calins_id, con_tree_path
        ;
    return null
    ;
    end
$$ language plpgsql
;

create or replace function create_condition_instances ()
    returns integer
    volatile
as $$
    begin
        update condition_instances as upd
        set con_tree_path = (
                select count(*) + 1
                from call_dependences
                where calins_id = upd.calins_id
                )::integer
                || con_tree_path
        where exists (
            select null
            from call_dependences
            where calins_id = upd.calins_id
            )
        ;
        insert into condition_instances
            (   con_tree_path
            ,   calins_id
            ,   con_connective
            )
        select distinct
                ARRAY[]::integer[]
            ,   calins_id
            ,   'AND'::connective
        from
            call_dependences as cd
        where
            exists (
                select null
                from condition_instances
                where calins_id = cd.calins_id
                )
            or (select count(*) from call_dependences where calins_id = cd.calins_id) > 1
        ;
        insert into condition_instances
            (   con_tree_path
            ,   calins_id
            ,   calins_id_con
            ,   cal_name
            ,   cal_identifier
            ,   run_status
            )
        select distinct
                ARRAY[row_number() over (partition by cd.calins_id order by cd.calins_id_x)]::integer[]
            ,   cd.calins_id
            ,   ci.calins_id
            ,   ci.cal_name
            ,   ci.cal_identifier
            ,   'SUCCEEDED'::run_status
        from call_dependences as cd
        join call_instances   as ci on ci.calins_id = cd.calins_id_x
        where
            exists (
                select null
                from condition_instances
                where calins_id = cd.calins_id
                )
            or (select count(*) from call_dependences where calins_id = cd.calins_id) > 1
        union all
        select distinct
                ARRAY[]::integer[]
            ,   cd.calins_id
            ,   ci.calins_id
            ,   ci.cal_name
            ,   ci.cal_identifier
            ,   'SUCCEEDED'::run_status
        from call_dependences as cd
        join call_instances   as ci on ci.calins_id = cd.calins_id_x
        where
            not exists (
                select null
                from condition_instances
                where calins_id = cd.calins_id
                )
            and (select count(*) from call_dependences where calins_id = cd.calins_id) = 1
        ;
    return null
    ;
    end
$$ language plpgsql
;

/******************************************************************************/
/* Schedules                                                                  */
/******************************************************************************/

create or replace view normalized_schedules as
select  sch_id
    ,   (sch_record).minute
    ,   (sch_record).hour
    ,   (sch_record).day_of_month
    ,   (sch_record).month
    ,   (sch_record).day_of_week
from
    (
    select  sch_id
        ,   unnest(sch_record)::schedule_record as sch_record
    from schedules
    ) as sch
;

create or replace function get_calins_id
    (   i_run_id integer
    )   returns  integer
    stable
as $$
    declare
        o_calins_id integer;
    begin
        select calins_id
            into o_calins_id 
        from runs
        where run_id = i_run_id 
        ;    
        return o_calins_id
        ; 
    end
$$ language plpgsql
;

create or replace function get_feature
    (   i_run_id integer
    ,   i_name   text
    )   returns  text
as $$
    declare
        val text;
    begin
        select (feature).value
        into val
        from (
            select unnest(tsk_feature) as feature
            from call_instances
            where calins_id = get_calins_id(run_id)
            ) as t
        where (feature).name = i_name
        ;
        return val
        ;
    end
$$ language plpgsql
;

create or replace function get_sch_id
    (   i_run_id integer
    )   returns  integer
as $$
    declare
        o_sch_id integer;
    begin
        select sch_id
        into o_sch_id
        from schedules
        where name = get_feature(i_run_id, 'schedule')
        ;
        return o_sch_id
        ;
    end
$$ language plpgsql
;

create or replace function get_run_ts
    (   i_run_ts timestamp
    ,   i_sch_id integer
    ,   i_shift  integer
    )   returns  timestamp
    stable
as $$
declare
    o_run_ts    timestamp;
    v_interval  interval  := '1 minute'::interval;
    v_run_shift integer   := i_shift;
    v_run_ts    timestamp := i_run_ts - v_run_shift * v_interval;
begin
    with recursive x (run_ts, cnt) as (
        (select v_run_ts, v_run_shift)
        union all
        select  x.run_ts + v_run_shift * v_interval
            ,   x.cnt - (case when sch.sch_id is null then 0 else 1 end)
        from x
        left join normalized_schedules as sch
            on  ARRAY[extract(month  from x.run_ts)]::integer[] <@ sch.month::integer[]
            and (   ARRAY[extract(day from x.run_ts)]::integer[] <@ sch.day_of_month::integer[]
                or  sch.day_of_month[1] = 0 and extract(month from x.run_ts) <> extract(month from (x.run_ts + interval '1 day'))
                ) 
            and ARRAY[extract(dow    from x.run_ts)]::integer[] <@ sch.day_of_week::integer[]
            and ARRAY[extract(hour   from x.run_ts)]::integer[] <@ sch.hour::integer[]
            and ARRAY[extract(minute from x.run_ts)]::integer[] <@ sch.minute::integer[]
            and sch.sch_id = i_sch_id
        where x.cnt >= 0
        )
    select run_ts
    into o_run_ts
    from x
    where cnt < 0
    ;
    return o_run_ts
    ;
end
$$ language plpgsql
;

/******************************************************************************/
/* Executor                                                                   */
/******************************************************************************/

create or replace function get_calins_name
    (   i_run_id integer
    )   returns text
    stable
as $$
declare
    o_cal_name text;
begin
    select tsk_name || coalesce('("' || array_to_string(cal_identifier, '" "') || '")', '')
    into o_cal_name 
    from call_instances
    where calins_id = get_calins_id(run_id)
    ;    
    return o_cal_name
    ; 
end
$$ language plpgsql
;

create or replace function get_tsk_name
    (   i_run_id integer
    )   returns text
    stable
as $$
    declare
        o_tsk_name text;
    begin
        select tsk_name
            into o_tsk_name 
        from call_instances
        where calins_id = get_calins_id(run_id)
        ;    
        return o_tsk_name
        ; 
    end
$$ language plpgsql
;

create or replace function get_executor
    (   i_calins_id integer
    )   returns text
    stable
as $$
    begin
        return get_feature(i_calins_id, 'executor')
        ;
    end
$$ language plpgsql
;

/*
create or replace function get_exe_name
    (   i_calins_id integer
    )   returns text
    stable
as $$
    begin
        return regexp_replace(get_executor(i_calins_id), ':.*$', '')
        ; 
    end
$$ language plpgsql
;
*/

create or replace function get_exeins_name
    (   i_calins_id integer
    )   returns text
    stable
as $$
begin
    return regexp_replace(get_executor(i_calins_id), '^.*:', '')
    ; 
end
$$ language plpgsql
;

create or replace function get_calins_features
    (   i_calins_id integer
    )   returns     setof text
as $$
begin
    return query
        select (feature).name||'="'||(feature).value||'"'
        from (
            select unnest(tsk_feature) as feature
            from call_instances
            where calins_id = i_calins_id
            ) as t
    ;
end
$$ language plpgsql
;

create or replace function set_new_run
    (   i_calins_id integer
    ,   i_run_ts    timestamp
    )   returns     integer
as $$
begin
    insert into runs (calins_id, run_ts, run_status_log) values (i_calins_id, i_run_ts, ARRAY[('SUBMITTED', current_timestamp)]::run_status_log);
end
$$ language plpgsql
;

create or replace function set_next_run
    (   i_run_id integer
    )   returns     integer
as $$
begin
    insert into runs (calins_id, run_ts, run_status_log)
    values (i_calins_id, i_run_ts, ARRAY[('SUBMITTED', current_timestamp)]::run_status_log);
end
$$ language plpgsql
;

/*
insert into runs (calins_id, run_ts, run_status) values (41, timestamp '2015-10-06 00:00:00', ARRAY[(timestamp '2015-10-05 03:00:23', 'SUBMITTED')]::RUN_STATUS_LOG[])
;
insert into runs (calins_id, run_ts, run_status) values                        (37, timestamp '2015-10-06 00:00:00', ARRAY[(timestamp '2015-10-06 02:01:35', 'SUCCEEDED'), (timestamp '2015-10-06 01:42:18', 'RUNNING'), (timestamp '2015-10-05 02:12:55', 'SUBMITTED')]::RUN_STATUS_LOG[])
;
insert into runs (calins_id, run_ts, run_status) values (38, timestamp '2015-10-06 00:00:00', ARRAY[(timestamp '2015-10-06 02:01:35', 'SUCCEEDED'), (timestamp '2015-10-06 01:42:18', 'RUNNING'), (timestamp '2015-10-05 02:12:55', 'SUBMITTED')]::RUN_STATUS_LOG[])
;
insert into runs (calins_id, run_ts, run_status) values (39, timestamp '2015-10-06 00:00:00', ARRAY[(timestamp '2015-10-06 02:01:35', 'SUCCEEDED'), (timestamp '2015-10-06 01:42:18', 'RUNNING'), (timestamp '2015-10-05 02:12:55', 'SUBMITTED')]::RUN_STATUS_LOG[])
;
insert into runs (calins_id, run_ts, run_status) values (15, timestamp '2015-10-06 00:00:00', ARRAY[(timestamp '2015-10-05 02:12:55', 'SUBMITTED')]::RUN_STATUS_LOG[])
;
insert into runs (calins_id, run_ts, run_status) values (11, timestamp '2015-10-06 00:00:00', ARRAY[(timestamp '2015-10-06 02:01:35', 'SUCCEEDED'), (timestamp '2015-10-06 01:42:18', 'RUNNING'), (timestamp '2015-10-05 02:12:55', 'SUBMITTED')]::RUN_STATUS_LOG[])
;
insert into runs (calins_id, run_ts, run_status) values (50, timestamp '2015-10-06 00:00:00', ARRAY[(timestamp '2015-10-05 02:12:55', 'SUBMITTED')]::RUN_STATUS_LOG[])
;
insert into runs (calins_id, run_ts, run_status) values (51, timestamp '2015-10-06 00:00:00', ARRAY[(timestamp '2015-10-06 02:01:35', 'SUCCEEDED'), (timestamp '2015-10-06 01:42:18', 'RUNNING'), (timestamp '2015-10-05 02:12:55', 'SUBMITTED')]::RUN_STATUS_LOG[])
;
insert into runs (calins_id, run_ts, run_status) values (54, timestamp '2015-10-06 00:00:00', ARRAY[(timestamp '2015-10-06 02:01:35', 'SUCCEEDED'), (timestamp '2015-10-06 01:42:18', 'RUNNING'), (timestamp '2015-10-05 02:12:55', 'SUBMITTED')]::RUN_STATUS_LOG[])
;

*/
create or replace view call_instance_features
    (   calins_id
    ,   fea_name
    ,   fea_value
    ) as
select  calins_id
    ,   (cal_feature).name
    ,   (cal_feature).value
from
    (
    select  calins_id
        ,   unnest(cal_feature) as cal_feature
    from call_instances
    ) as t
where (cal_feature).name is not null
;

create or replace view run_features
    (   run_id
    ,   fea_name
    ,   fea_value
    ) as
select  r.run_id
    ,   cif.fea_name
    ,   cif.fea_value
from runs as r
join call_instance_features as cif
    on  cif.calins_id = r.calins_id
;

create or replace view executor_features
    (   exe_id
    ,   fea_name
    ,   fea_value
    ) as
select  exe_id
    ,   (exe_feature).name
    ,   (exe_feature).value
from
    (
    select  exe_id
        ,   unnest(exe_feature) as exe_feature
    from executors
    ) as t
;

create or replace function get_ready_runs()
    returns setof integer
as
$$
declare
    v_row_count integer;
begin
    drop table if exists tmp_1 cascade
    ;
    create temporary table tmp_1
        (   calins_id integer
        ,   con_tree_path integer[]
        ,   result boolean
        ,   run_id integer
        )
    ;
    drop table if exists tmp_2 cascade
    ;
    create temporary table tmp_2 as select * from tmp_1
    ;
    insert into tmp_1
    (   run_id
    ,   calins_id
    ,   con_tree_path
    ,   result
    )
    select
        r1.run_id
    ,   ci.calins_id
    ,   ci.con_tree_path
    ,   coalesce(ci.run_status = (r2.run_status[1]).run_status, false)
    from runs as r1
    join condition_instances as ci
        on ci.calins_id = r1.calins_id
    join call_instance_features as c
        on c.calins_id = ci.calins_id_con
    join schedules as s
        on s.sch_name = c.fea_value
    left outer join runs as r2
        on  r2.calins_id = ci.calins_id_con
        and r2.run_ts = get_run_ts(r1.run_ts, s.sch_id, 0)
    where   (r1.run_status[1]).run_status = 'SUBMITTED'
        and c.fea_name = 'schedule'
    ;
    get diagnostics v_row_count = ROW_COUNT
    ;
    while v_row_count > 0
    loop
        insert into tmp_2
        (   run_id
        ,   calins_id
        ,   con_tree_path
        ,   result
        )
        select
            rcl.run_id
        ,   rcl.calins_id
        ,   coalesce(op.con_tree_path, array[]::integer[]) as con_tree_path
        ,   case op.con_connective
                when 'AND' then bool_and(rcl.result)
                when 'OR'  then bool_or(rcl.result)
                when 'NOT' then not bool_and(rcl.result)
                else bool_and(rcl.result)
            end as result
        from tmp_1 as rcl
        join condition_instances as op
            on  (op.calins_id, op.con_tree_path) = (rcl.calins_id, array_all_but_last(rcl.con_tree_path))
        group by
            rcl.run_id
        ,   rcl.calins_id
        ,   op.con_tree_path
        ,   op.con_connective
        ;
        get diagnostics v_row_count = ROW_COUNT
        ;
        delete from tmp_1 as x
        using tmp_2 as y
        where   y.calins_id = x.calins_id
            and y.con_tree_path = array_all_but_last(x.con_tree_path)
        ;
        insert into tmp_1 select * from tmp_2
        ;
        truncate table tmp_2
        ;
    end loop
    ;
    return query
        select
            run_id
        from
            (
            select
                tmp.run_id
            ,   exc.fea_value::integer as exe_capacity
            ,   sum(coalesce(cic.fea_value::integer, 1)) over
                    (   partition by exe.exe_id
                        order by
                            cii.fea_value::integer desc nulls last
                        ,   cic.fea_value::integer      nulls first
                        rows between unbounded preceding and current row
                    ) as calins_capacity_sum
            from tmp_1 as tmp
            join call_instance_features as cie
                on  cie.calins_id = tmp.calins_id
                and cie.fea_name = 'executor'
            join executors as exe
                on  exe.exe_name = cie.fea_value
            left join executor_features as exc
                on  exc.exe_id = exe.exe_id
                and exc.fea_name = 'capacity'
            left join call_instance_features as cic
                on  cic.calins_id = tmp.calins_id
                and cic.fea_name = 'capacity'
            left join call_instance_features as cii
                on  cii.calins_id = tmp.calins_id
                and cii.fea_name = 'importance'
            ) as t
        where
            calins_capacity_sum <= exe_capacity
            or  exe_capacity is null
    ;
end
$$
language plpgsql
;

create or replace function set_run_status
    (   i_run_id integer
    ,   i_status run_status
    ) returns integer
as
$$
begin
    update runs
    set run_status = (current_timestamp, i_status)::run_status_log || run_status
    where run_id = i_run_id
    ;
    return 0
    ;
end
$$
language plpgsql
;

create or replace function get_run_features
    (   i_run_id integer
    ) returns setof text
as
$$
begin
    return query
        select fea_name || '="' || fea_value || '"'
        from run_features
        where run_id = i_run_id
    ;
    return query
        select 'run_ts="' || run_ts || '"'
        from runs
        where run_id = i_run_id
    ;
end
$$
language plpgsql
;

create or replace function get_calins_name
    (   i_run_id integer
    ) returns text
as
$$
declare
    v_result text;
begin
    select ci.cal_name
    into v_result
    from runs as r
    join call_instances as ci
        on ci.calins_id = r.calins_id
    where   r.run_id = i_run_id
    ;
    return v_result
    ;
end
$$
language plpgsql
;

create or replace function get_exe_name
    (   i_run_id integer
    ) returns text
as
$$
declare
    v_result text;
begin
    select rf.fea_value
    into v_result
    from runs as r
    join run_features as rf
        on  rf.run_id = r.run_id
        and rf.fea_name = 'executor'
    where   r.run_id = i_run_id
    ;
    return v_result
    ;
end
$$
language plpgsql
;

create or replace function get_exe_type
    (   i_run_id integer
    ) returns text
as
$$
declare
    v_result text;
begin
    select e.exe_type
    into v_result
    from runs as r
    join run_features as rf
        on  rf.run_id = r.run_id
        and rf.fea_name = 'executor'
    join executors as e
        on e.exe_name = rf.fea_value
    where   r.run_id = i_run_id
    ;
    return v_result
    ;
end
$$
language plpgsql
;

create or replace function get_tsk_type
    (   i_run_id integer
    ) returns text
as
$$
declare
    v_result task_type;
begin
    select ci.tsk_type
    into v_result
    from runs as r
    join call_instances as ci
        on  ci.calins_id = r.calins_id
    where   r.run_id = i_run_id
    ;
    return v_result
    ;
end
$$
language plpgsql
;

-- checks:
-- 1. Each call instance must have its schedule.
-- 2. Each call instance must have its executor.
