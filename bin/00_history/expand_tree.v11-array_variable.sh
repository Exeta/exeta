#!/bin/bash

set -e
#set -x

sql_client="psql postgres --tuples-only --no-align"
exeta_home=/home/martin/Exeta/tutorial
schema="exeta"
main_task_name="main"
instance_name_length=16
instance_name_prefix=$( for (( i=0 ; i < ${instance_name_length} ; i++ )) ; do echo -n "0" ; done )

#declare -A TimeStamp=( [YYYY-MM-DD HH24:MI:SS]="2017-08-19 13:38:58" [YYYY-MM-DD]="2017-08-19" [HH24:MI:SS]="13:38:58" [YYYYMMDDHH24MISS]="20170819133858" [YYYYMMDD]="20170819" [HH24MISS]="133858" )

sql () {
    # $1 = SQL statement
    ${sql_client} <<EOF
${1}
EOF
}

set_feature () {
    feature[${n}]="${1}"
    if [ "${feature[${n}]}" != "" ]
    then
        #echo "feature["${n}"]="${feature[${n}]}
        n=$(( n + 1 ))
    fi
}

put_features () {
    for i in $( seq 0 ${n} ) ; do echo ${feature[${i}]} ; done
}

unset_features () {
    while :
    do
        n=$(( ${n} - 1 ))
        if [ "feature[${n}]" != "#" ] ; then break ; fi
    done
}

task_features () {
    # shift the control list if exists
    if [ "${control_list}" != "" ]
    then
        set_feature "${control_list}=( \${${control_list}[@]:$(( ${max_position} - ${member_position} ))} )"
    fi
    for p in $( sql "select position from ${schema}.task_features where task_id = ${task_id} order by position" )
    do
        set_feature "$( sql "select feature || '=' || value from ${schema}.task_features where task_id = ${task_id} and position = ${p}" )"
    done
}

call_identifiers () {
    for p in $( sql "select position from ${schema}.task_identifiers where task_id = ${task_id} order by position" )
    do
        if [ "${control_list}" == "" ] || [ ${p} -lt ${member_position} ]
        then
            set_feature "$( sql "
                select i.identifier || '=' || v.identifier
                from       (select * from ${schema}.task_identifiers where task_id = ${task_id} and position = ${p}) as i
                cross join (select * from ${schema}.call_identifiers where call_id = ${call_id} and position = ${p}) as v
                " )"
        else
            set_feature "$( sql "
                select identifier || '=\${${control_list}[$(( ${p} - ${member_position} ))]}'
                from ${schema}.task_identifiers
                where task_id = ${task_id} and position = ${p}
                order by position
                " )"
        fi
    done
}

call_features () {
    for p in $( sql "select position from ${schema}.call_features where call_id = ${call_id} order by position" )
    do
        set_feature "$( sql "select feature || '=' || value from ${schema}.call_features where call_id = ${call_id} and position = ${p}" )"
    done
}

merge_instance () {
bash <<EOF
$(
put_features
echo "${sql_client} <<EOF"
echo "with src (name) as (select array['${task_name}'"
sql "select ',''\${' || identifier || '}''' from ${schema}.task_identifiers where task_id = ${task_id} and position < $(if [ "${control_list}" == "" ] ; then echo ${max_position} ; else echo ${member_position} ; fi) order by position"
if [ "${control_list}" != "" ] ; then echo ",'( \${${control_list}[@]} )'" ; fi
echo "]::text[] as name)
, upd (id) as (update      ${schema}.instances set active = true                         where name     in (select name from src)                 returning id)
, ins (id) as (insert into ${schema}.instances (name, active) select name, true from src where name not in (select name from ${schema}.instances) returning id)
select id from upd
union all
select id from ins
"
echo "EOF"
)
EOF
}

empty_list () {
bash <<EOF
$(
put_features
sql "
    select 'echo ' || case when t.member_position is null then '1' else '\${#' || v.identifier || '[@]}' end
    from            (select * from ${schema}.tasks            where      id = ${task_id}) as t
    left outer join (select * from ${schema}.task_identifiers where task_id = ${task_id}) as v on v.position  = t.member_position - 1
    "
)
EOF
}

instance_name () {
    echo ${instance_name_prefix}${instance_id} | sed -e "s/\(0*\)\([[:digit:]]\{${instance_name_length},${instance_name_length}\}\)/\2/"
}

task_name () {
bash <<EOF
$(
put_features
sql "select 'echo ' || name from ${schema}.calls where id = ${call_id}"
)
EOF
}

server () {
bash <<EOF
$(
put_features
if [ "${task_type}" == "execute" ]
then
    echo "echo \${executor}"
elif [ "${task_type}" == "generate" ]
then
    echo "echo \${generator}"
fi
)
EOF
}

server_type () {
    server_location=$( find ${exeta_home}/rep -name "${server}" )
    case $( echo "${server_location}" | wc -w ) in
    0)
        echo "ERROR: The server ${server} does not exist in ${exeta_home}/rep!" >&2
        ;;
    1)
        echo ${server_location} | sed -e "s/^.*\/\(.*\)\/srv\/${server}/\1/"
        ;;
    *)
        echo "ERROR: The server ${server} is ambiguous, it exists in following locations: ${server_location}!" >&2
        ;;
    esac
}

#instance_and_features () {
#    set_feature "#"
#    call_identifiers
#    instance_id=( $( merge_instance ) ${instance_id[@]} )
#    instance_name=( $( instance_name ) ${instance_name[@]} )
#    task_features
#    call_features
#}

get_env () {
    server_type_dir=${exeta_home}/rep/${server_type}
    env_file=${server_type_dir}/bin/env
    if [ -d ${server_type_dir} ]
    then
        if [ -e ${env_file} ]
        then
            grep -e "^[[:blank:]]*${1}=" ${env_file} | sed -e "s/^[[:blank:]]*${1}=//"
        else
            echo "ERROR: Environment file ${env_file} does not exist!" >&2
        fi
    else
        echo "ERROR: Directory of the server type ${server_type} does not exist!" >&2
    fi
}

substitute_code () {
    server=$( server )
    server_type=$( server_type )
    sfx=$( get_env "sfx" )
    source_file_name=${exeta_home}/rep/${server_type}/src/${task_name}.${sfx}
    if [ -e "${source_file_name}" ]
    then
        bash <<EOF
$(
put_features
echo "cat > ${exeta_home}/rep/${server_type}/${task_type:0:3}/${instance_name}.${sfx} <<EOF"
cat ${source_file_name}
echo "EOF"
)
EOF
    else
        echo "ERROR: Source file ${source_file_name} does not exist!" >&2
    fi
}

expand_tree () {
    for call_id in $( sql "select call_id from ${schema}.call_leaves where dependent_task_id = ${task_id}" )
    do
        task_name=$( task_name )
        task_id=$( sql "select id from ${schema}.tasks where name = '${task_name}'" )
        if [ "${task_id}" != "" ]
        then
            if [ "$( empty_list )" != "0" ]
            then
                #instance_and_features
                max_position="$( sql "select coalesce(max(position) + 1, -1) from ${schema}.task_identifiers where task_id = ${task_id}" )"
                member_position="$( sql "select coalesce(member_position, -1) from ${schema}.tasks where id = ${task_id}" )"
                control_list="$( sql "select identifier from ${schema}.task_identifiers where task_id = ${task_id} and position = $(( ${member_position} - 1 ))" )"
                set_feature "#"
                call_identifiers
                instance_id=$( merge_instance )
                instance_name=$( instance_name )
		sql "select 'INSTANCE ${instance_name} : ' || name[1]::text || ' [ ' || array_to_string(name[2:array_length(name, 1)], ' ') || ' ]' from ${schema}.instances where id = ${instance_id}" >&2
                task_features
                call_features
                task_type=$( sql "select tt.name from ${schema}.tasks as t inner join ${schema}.task_types as tt on tt.id = t.task_type_id where t.id = '${task_id}'" )
                if   [ "${task_type}" != "call" ]
                then
                    substitute_code
                fi
                expand_tree
            fi
        else
            echo "ERROR: Task \"${task_name}\" does not exist!" >&2
        fi
    done
    unset_features
}

sql "update ${schema}.instances set active = false"

task_name=${main_task_name}
task_id=$( sql "select id from ${schema}.tasks where name = '${task_name}'" )
feature=(  )
n=0
max_position=-1
member_position=-1
control_list=""
instance_id=$( merge_instance )
set_feature "#"
task_features

expand_tree

