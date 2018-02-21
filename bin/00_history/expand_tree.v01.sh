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

        #echo FEATURES:
        #cat features.sh
        #echo TASK: ${depth} : ${task_name} : ${task_id}

        if [ "${task_id}" != "" ]
        then
            echo "#${depth}" >> features.sh
            call_identifiers ${call_id} ${task_id} >> features.sh
            call_features ${call_id} >> features.sh
            
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

if [ -e features.sh ] ; then rm features.sh ; fi
touch features.sh

depth=-1
expand_tree ${main_task_id}

