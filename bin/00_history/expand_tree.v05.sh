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
    sql "
        select i.identifier || '=' || replace(v.identifier, '''', '''''')
        from       (select * from ${schema}.tasks            where      id = ${task_id}) as t
        inner join (select * from ${schema}.task_identifiers where task_id = ${task_id}) as i on i.position < t.member_position or t.member_position is null
        inner join (select * from ${schema}.call_identifiers where call_id = ${call_id}) as v on v.position = i.position
        order by i.position
        "
    sql "
        select i.identifier || '=\${' || v.identifier || '[' || i.position - t.member_position || ']}'
        from       (select * from ${schema}.tasks            where      id = ${task_id} and member_position is not null) as t
        inner join (select * from ${schema}.task_identifiers where task_id = ${task_id}) as i on i.position >= t.member_position
        inner join (select * from ${schema}.task_identifiers where task_id = ${task_id}) as v on v.position  = t.member_position - 1
        order by i.position
        "
}

task_features () {
    sql "
        select v.identifier || '=( \${' || v.identifier || '[@]:' || i.max_position - v.position || '} )'
        from       (select *                             from ${schema}.tasks            where      id = ${task_id} and member_position is not null) as t
        inner join (select *                             from ${schema}.task_identifiers where task_id = ${task_id}) as v on v.position  = t.member_position - 1
        cross join (select max(position) as max_position from ${schema}.task_identifiers where task_id = ${task_id}) as i
        "
    sql "select feature || '=' || replace(value, '''', '''''') from ${schema}.task_features where task_id = ${task_id}"
}

call_features () {
    sql "select feature || '=' || replace(value, '''', '''''') from ${schema}.call_features where call_id = ${call_id}"
}

merge_instance () {
    cp features.sh instance.sh
    echo >> instance.sh
    echo "${sql_client} <<EOF" >> instance.sh
    echo "with src (name) as (select array['${task_name}'" >> instance.sh
    sql "
        select ',''' || case when t.member_position is not null and i.position = t.member_position - 1 then '( \${' || identifier || '[@]} )' else '\${' || identifier || '}' end || ''''
        from       (select * from ${schema}.tasks            where      id = ${task_id}) as t
        inner join (select * from ${schema}.task_identifiers where task_id = ${task_id}) as i on i.position < t.member_position or t.member_position is null
        order by position
        " >> instance.sh
    echo "]::text[] as name)
    , upd (id) as (update      ${schema}.instances set active = true                         where name     in (select name from src)                 returning id)
    , ins (id) as (insert into ${schema}.instances (name, active) select name, true from src where name not in (select name from ${schema}.instances) returning id)
    select id from upd
    union all
    select id from ins
    " >> instance.sh
    echo "EOF" >> instance.sh
    #cat instance.sh
    #echo
    bash instance.sh
}

empty_list () {
    cp features.sh empty_list.sh
    sql "
        select 'echo ' || case when t.member_position is null then '1' else '\${#' || v.identifier || '[@]}' end
        from            (select * from ${schema}.tasks            where      id = ${task_id}) as t
        left outer join (select * from ${schema}.task_identifiers where task_id = ${task_id}) as v on v.position  = t.member_position - 1
        " >> empty_list.sh
    bash empty_list.sh
}

expand_tree () {

    depth=$((depth + 1))

    for call_id in $( sql "select call_id from ${schema}.call_leaves where dependent_task_id = ${task_id}" )
    do
        cp features.sh task_name.sh
        sql "select 'echo ' || name from ${schema}.calls where id = ${call_id}" >> task_name.sh
        task_name=$( bash task_name.sh )
        task_id=$( sql "select id from ${schema}.tasks where name = '${task_name}'" )

        if [ "${task_id}" != "" ]
        then
            if [ "$( empty_list )" != "0" ]
            then
                echo "#${depth}" >> features.sh
                call_identifiers >> features.sh
                instance_id=$( merge_instance )
                task_features >> features.sh
                call_features >> features.sh
                cp features.sh $( echo 0000000000000000${instance_id} | sed -e "s/\(0*\)\([[:digit:]]\{16,16\}\)/\2/" ).sh
                
                expand_tree
            
                sed -e "/\#${depth}/,$ d" features.sh > .features.sh
                mv .features.sh features.sh
            fi
        else
            echo "ERROR: Task \"${task_name}\" does not exists!"
        fi
    done
    
    depth=$((depth - 1))

}

sql "update ${schema}.instances set active = false"

depth=0
task_name=${main_task_name}
task_id=$( sql "select id from ${schema}.tasks where name = '${task_name}'" )
echo "#${depth}" > features.sh
task_features >> features.sh
instance_id=$( merge_instance )
cp features.sh $( echo 0000000000000000${instance_id} | sed -e "s/\(0*\)\([[:digit:]]\{16,16\}\)/\2/" ).sh

expand_tree

#exit 0

rm features.sh task_name.sh empty_list.sh instance.sh

