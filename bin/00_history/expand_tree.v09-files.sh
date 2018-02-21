#!/bin/bash

set -e
#set -x

sql_client="psql postgres --tuples-only --no-align"
exeta_home=/home/martin/Exeta/tutorial
schema="exeta"
main_task_name="main"
file_name_length=16
file_name_prefix=$( for (( i=0 ; i < ${file_name_length} ; i++ )) ; do echo -n "0" ; done )

#declare -A TimeStamp=( [YYYY-MM-DD HH24:MI:SS]="2017-08-19 13:38:58" [YYYY-MM-DD]="2017-08-19" [HH24:MI:SS]="13:38:58" [YYYYMMDDHH24MISS]="20170819133858" [YYYYMMDD]="20170819" [HH24MISS]="133858" )

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
    cp .features.sh .instance.sh
    echo >> .instance.sh
    echo "${sql_client} <<EOF" >> .instance.sh
    echo "with src (name) as (select array['${task_name}'" >> .instance.sh
    sql "
        select ','''
            ||  case
                when t.member_position is not null and i.position = t.member_position - 1
                then '( \${' || identifier || '[@]} )'
                else '\${' || identifier || '}'
                end
            || ''''
        from       (select * from ${schema}.tasks            where      id = ${task_id}) as t
        inner join (select * from ${schema}.task_identifiers where task_id = ${task_id}) as i on i.position < t.member_position or t.member_position is null
        order by position
        " >> .instance.sh
    echo "]::text[] as name)
    , upd (id) as (update      ${schema}.instances set active = true                         where name     in (select name from src)                 returning id)
    , ins (id) as (insert into ${schema}.instances (name, active) select name, true from src where name not in (select name from ${schema}.instances) returning id)
    select id from upd
    union all
    select id from ins
    " >> .instance.sh
    echo "EOF" >> .instance.sh
    bash .instance.sh
    rm .instance.sh
}

empty_list () {
    cp ${instance_name}.sh .empty_list.sh
    sql "
        select 'echo ' || case when t.member_position is null then '1' else '\${#' || v.identifier || '[@]}' end
        from            (select * from ${schema}.tasks            where      id = ${task_id}) as t
        left outer join (select * from ${schema}.task_identifiers where task_id = ${task_id}) as v on v.position  = t.member_position - 1
        " >> .empty_list.sh
    bash .empty_list.sh
    rm .empty_list.sh
}

instance_file_name () {
    echo ${file_name_prefix}${instance_id} | sed -e "s/\(0*\)\([[:digit:]]\{${file_name_length},${file_name_length}\}\)/\2/"
}

call_id_list () {
    sql "select call_id from ${schema}.call_leaves where dependent_task_id = ${task_id}"
}

task_name () {
    cp ${instance_name}.sh .task_name.sh
    sql "select 'echo ' || name from ${schema}.calls where id = ${call_id}" >> .task_name.sh
    bash .task_name.sh
    rm .task_name.sh
}

task_id () {
    sql "select id from ${schema}.tasks where name = '${task_name}'"
}

task_type () {
    sql "select tt.name from ${schema}.tasks as t inner join ${schema}.task_types as tt on tt.id = t.task_type_id where t.id = '${task_id}'"
}

server () {
    cp ${instance_name}.sh .server.sh
    if [ "${task_type}" == "execute" ]
    then
        echo "echo \${executor}" >> .server.sh
    elif [ "${task_type}" == "generate" ]
    then
        echo "echo \${generator}" >> .server.sh
    fi
    bash .server.sh
    rm .server.sh
}

server_type () {
    find ${exeta_home}/rep -name "${server}" | sed -e "s/^.*\/\(.*\)\/srv\/${server}/\1/"
}

instance_and_features () {
    cp ${instance_name}.sh .features.sh
    echo "# $(( ${#instance_id[@]} + 1))" >> .features.sh
    call_identifiers >> .features.sh
    instance_id=( $( merge_instance ) ${instance_id[@]} )
    instance_name=( $( instance_file_name ) ${instance_name[@]} )
    mv .features.sh ${instance_name}.sh
    task_features >> ${instance_name}.sh
    call_features >> ${instance_name}.sh
}

get_env () {
    grep -e "^[[:blank:]]*${1}=" ${exeta_home}/rep/${server_type}/bin/env | sed -e "s/^[[:blank:]]*${1}=//"
}

substitute_code () {
    server=$( server )
    server_type=$( server_type )
    echo ${server} ${server_type}
    sfx=$( get_env "sfx" )
    #echo "Instance ${instance_name} of task ${task_name}.${sfx} ${task_type}d by ${server}."
    source_file_name=${exeta_home}/rep/${server_type}/src/${task_name}.${sfx}
    if [ -f "${source_file_name}" ]
    then
        cp ${instance_name}.sh .code.sh
        echo "cat > ${exeta_home}/rep/${server_type}/${task_type:0:3}/${instance_name}.${sfx} <<EOF" >> .code.sh
        cat ${source_file_name} >> .code.sh
        echo "EOF" >> .code.sh
        #view .code.sh
        bash .code.sh
        rm .code.sh
    else
        echo "ERROR: Source file ${source_file_name} does not exist!"
    fi
}

expand_tree () {
    for call_id in $( call_id_list )
    do
        task_name=$( task_name )
        task_id=$( task_id )
        if [ "${task_id}" != "" ]
        then
            if [ "$( empty_list )" != "0" ]
            then
                instance_and_features
                task_type=$( task_type )
                if   [ "${task_type}" != "call" ]
                then
                    substitute_code
                fi
                expand_tree
            fi
        else
            echo "ERROR: Task \"${task_name}\" does not exist!"
        fi
    done
    instance_name=( ${instance_name[@]:1} )
    instance_id=( ${instance_id[@]:1} )
}

sql "update ${schema}.instances set active = false"

task_name=${main_task_name}
task_id=$( task_id )
touch .features.sh
instance_id=$( merge_instance )
instance_name=$( instance_file_name )
echo "# 0" > ${instance_name}.sh
task_features >> ${instance_name}.sh

expand_tree

