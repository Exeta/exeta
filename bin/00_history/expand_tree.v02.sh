#!/bin/bash

schema="exeta"
main_task_name="main"

sql () {
    # $1 ... sql_command
    psql postgres --tuples-only --no-align --command="${1}"
}

call_identifiers () {
    sql "
        select t.identifier || '=\"' || c.identifier || '\"'
        from ${schema}.task_identifiers as t
        inner join ${schema}.call_identifiers as c
        on c.position = t.position and c.call_id = ${1}
        where t.task_id = ${2}
        "
}

task_features () {
   sql "select feature || '=\"' || value || '\"' from ${schema}.task_features where task_id = ${1}"
}

call_features () {
    sql "select feature || '=\"' || value || '\"' from ${schema}.call_features where call_id = ${1}"
}

expand_tree () {
    
    task_id=${1}

    depth=$((depth + 1))

    task_features ${task_id} >> features.sh
    for call_id in $( sql "select call_id from ${schema}.call_leaves where dependent_task_id = ${task_id}" )
    do
        cp features.sh task_name.sh
        sql "select 'echo ' || name from ${schema}.calls where id = ${call_id}" >> task_name.sh
        task_name=$( sh task_name.sh )
        task_id=$( sql "select id from ${schema}.tasks where name = '${task_name}'" )

        if [ "${task_id}" != "" ]
        then
            echo "#${depth}" >> features.sh
            call_identifiers ${call_id} ${task_id} >> features.sh
            call_features ${call_id} >> features.sh

            # substitute '' for ' in identifier values
            # add list and recursion handling

            cp features.sh instance.sh
            echo >> instance.sh
            echo "psql postgres --tuples-only --no-align <<EOF" >> instance.sh
            echo "with src (name) as (select array['${task_name}'" >> instance.sh
            sql "select ',''\${' || identifier || '}''' from ${schema}.task_identifiers where task_id = ${task_id} order by position" >> instance.sh
            echo "]::text[] as name)
            , upd (operation, name) as (update ${schema}.instances set active = true where name in (select name from src) returning 'UPDATE'::text, name)
            , ins (operation, name) as (insert into ${schema}.instances (name, active) select name, true from src where name not in (select name from ${schema}.instances) returning 'INSERT'::text, name)
            select operation, name from upd union all select operation, name from ins" >> instance.sh
            echo "EOF" >> instance.sh
            #cat instance.sh
            #echo
            sh instance.sh
            
            expand_tree ${task_id}
            
            sed -e "/\#${depth}/,$ d" features.sh > .features.sh
            mv .features.sh features.sh
        else
            echo "ERROR: Task \"${task_name}\" does not exists!"
        fi
    done
    
    depth=$((depth - 1))

}

main_task_id=$( sql "select id from ${schema}.tasks where name = '${main_task_name}'" )

sql "update ${schema}.instances set active = false"

sql "
with src (name) as (select array['${main_task_name}']::text[])
, upd (operation, name) as (update ${schema}.instances set active = true where name in (select name from src) returning 'UPDATE'::text, name)
, ins (operation, name) as (insert into ${schema}.instances (name, active) select name, true from src where name not in (select name from ${schema}.instances) returning 'INSERT'::text, name)
select operation, name from upd union all select operation, name from ins
"

depth=0

echo "#${depth}" > features.sh

expand_tree ${main_task_id}

