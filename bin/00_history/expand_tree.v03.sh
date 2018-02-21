#!/bin/bash

sql_client="psql postgres --tuples-only --no-align"
schema="exeta"
main_task_name="main"

sql () {
    # $1 = SQL statement
    ${sql_client} <<EOF
${1}
EOF
}

call_identifiers () {
    # $1 = call id
    # $2 = task id
    sql "
        select i.identifier || '=' || replace(v.identifier, '''', '''''')
        from       (select * from ${schema}.tasks            where      id = ${2}) as t
        inner join (select * from ${schema}.task_identifiers where task_id = ${2}) as i on i.position < t.member_position or t.member_position is null
        inner join (select * from ${schema}.call_identifiers where call_id = ${1}) as v on v.position = i.position
        order by i.position
        "
    sql "
        select v.identifier || '=( \${' || v.identifier || '[@]} )'
        from       (select * from ${schema}.tasks            where      id = ${2} and member_position is not null) as t
        inner join (select * from ${schema}.task_identifiers where task_id = ${2}) as v on v.position  = t.member_position - 1
        "
    sql "
        select i.identifier || '=\${' || v.identifier || '[' || i.position - t.member_position || ']}'
        from       (select * from ${schema}.tasks            where      id = ${2} and member_position is not null) as t
        inner join (select * from ${schema}.task_identifiers where task_id = ${2}) as i on i.position >= t.member_position
        inner join (select * from ${schema}.task_identifiers where task_id = ${2}) as v on v.position  = t.member_position - 1
        order by i.position
        "
}

task_features () {
    # $1 = task id
    sql "select feature || '=' || replace(value, '''', '''''') from ${schema}.task_features where task_id = ${1}"
}

call_features () {
    # $1 = call id
    sql "
        select v.identifier || '=( \${' || v.identifier || '[@]:' || i.max_position - v.position || '} )'
        from       (select *                             from ${schema}.tasks            where      id = ${2} and member_position is not null) as t
        inner join (select *                             from ${schema}.task_identifiers where task_id = ${2}) as v on v.position  = t.member_position - 1
        cross join (select max(position) as max_position from ${schema}.task_identifiers where task_id = ${2}) as i
        "
    sql "select feature || '=' || replace(value, '''', '''''') from ${schema}.call_features where call_id = ${1}"
}

merge_instance () {
    # $1 = task name
    # $2 = task id
    cp features.sh instance.sh
    echo >> instance.sh
    echo "${sql_client} <<EOF" >> instance.sh
    echo "with src (name) as (select array['${1}'" >> instance.sh
    sql "
        select ',''' || case when t.member_position is not null and i.position = t.member_position - 1 then '( \${' || identifier || '[@]} )' else '\${' || identifier || '}' end || ''''
        from       (select * from ${schema}.tasks            where      id = ${2}) as t
        inner join (select * from ${schema}.task_identifiers where task_id = ${2}) as i on i.position < t.member_position or t.member_position is null
        order by position
        " >> instance.sh
    echo "]::text[] as name)
    , upd (operation, name) as (update      ${schema}.instances set active = true                         where name     in (select name from src)                 returning 'UPDATE'::text, name)
    , ins (operation, name) as (insert into ${schema}.instances (name, active) select name, true from src where name not in (select name from ${schema}.instances) returning 'INSERT'::text, name)
    select operation, name from upd union all select operation, name from ins" >> instance.sh
    echo "EOF" >> instance.sh
    #cat instance.sh
    #echo
    bash instance.sh
}

empty_list () {
    # $1 = task id
    cp features.sh empty_list.sh
    sql "
        select 'echo ' || case when t.member_position is null then '1' else '\${#' || v.identifier || '[@]}' end
        from            (select * from ${schema}.tasks            where      id = ${1}) as t
        left outer join (select * from ${schema}.task_identifiers where task_id = ${1}) as v on v.position  = t.member_position - 1
        " >> empty_list.sh
    bash empty_list.sh
}

expand_tree () {

    # $1 = task id
    
    task_id=${1}

    depth=$((depth + 1))

    task_features ${task_id} >> features.sh
    for call_id in $( sql "select call_id from ${schema}.call_leaves where dependent_task_id = ${task_id}" )
    do
        cp features.sh task_name.sh
        sql "select 'echo ' || name from ${schema}.calls where id = ${call_id}" >> task_name.sh
        task_name=$( bash task_name.sh )
        task_id=$( sql "select id from ${schema}.tasks where name = '${task_name}'" )

        if [ "${task_id}" != "" ]
        then
            if [ "$( empty_list ${task_id} )" != "0" ]
            then
                echo "#${depth}" >> features.sh
                call_identifiers ${call_id} ${task_id} >> features.sh
                merge_instance ${task_name} ${task_id}
                call_features ${call_id} ${task_id} >> features.sh
            
                expand_tree ${task_id}
            
                sed -e "/\#${depth}/,$ d" features.sh > .features.sh
                mv .features.sh features.sh
            fi
        else
            echo "ERROR: Task \"${task_name}\" does not exists!"
        fi
    done
    
    depth=$((depth - 1))

}

main_task_id=$( sql "select id from ${schema}.tasks where name = '${main_task_name}'" )
sql "update ${schema}.instances set active = false"
depth=0
echo "#${depth}" > features.sh
merge_instance ${main_task_name} ${main_task_id}

expand_tree ${main_task_id}

#exit 0

rm features.sh task_name.sh empty_list.sh instance.sh

