#!/bin/bash

set -e
#set -x

sql_client="psql postgres --tuples-only --no-align"
schema="exeta"
main_task_name="main"
instance_name_length=16
instance_name_prefix=$( for (( i=0 ; i<instance_name_length ; i++ )) ; do echo -n "0" ; done )

#declare -A TimeStamp=(
#   [YYYY-MM-DD HH24:MI:SS]="2017-08-19 13:38:58"
#   [YYYY-MM-DD]="2017-08-19"
#   [HH24:MI:SS]="13:38:58"
#   [YYYYMMDDHH24MISS]="20170819133858"
#   [YYYYMMDD]="20170819"
#   [HH24MISS]="133858"
#   [YYYYMMDD_HH24MISS]="20170819_133858"
#   )

sql () {

    local statement="${1}"

    ${sql_client} <<EOF
${statement}
EOF

}

set_feature () {

    feature[n]="${1}"
    n=$((n+1))

}

put_features () {

    for (( i=0 ; i<n ; i++ ))
    do
        echo ${feature[i]}
    done

}

unset_features () {

    while :
    do
        unset feature[n]
        n=$((n-1))
        if [ "${feature[n]}" == "#" ]
        then
            break
        fi
    done

}

task_features () {

    #local task_id=${1}

    for p in $(sql "select position from ${schema}.task_features where task_id = ${1} order by position")
    do
        set_feature "$(sql "select name || '=' || value from ${schema}.task_features where task_id = ${1} and position = ${p}")"
    done

}

call_identifiers () {

#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! vyhodnotit vsechny call identifiers najednou, ne postupne

    #local task_id="${1}"
    #local call_id="${2}"

    for p in $(sql "select position from ${schema}.task_identifiers where task_id = ${1} and identifier_type_id = 0 order by position")
    do
        set_feature "$(sql "
            select i.name || '=' || v.value
            from       (select * from ${schema}.task_identifiers where task_id = ${1} and position = ${p}) as i
            cross join (select * from ${schema}.call_identifiers where call_id = ${2} and position = ${p}) as v
            ")"
    done

}

control_list_features () {

    #local task_id="${1}"

    local control_list="$(sql "select name from ${schema}.task_identifiers where task_id = ${1} and identifier_type_id = 1")"
    if [ "${control_list}" != "" ]
    then
        local first_position="$(sql "select position + 1 from ${schema}.task_identifiers where task_id = ${1} and identifier_type_id = 1")"
        local last_position=""
        for p in $(sql "select position from ${schema}.task_identifiers where task_id = ${1} and identifier_type_id = 2 order by position")
        do
            set_feature "$( sql "
                select name || '=\${${control_list}[$((p-first_position))]}'
                from (select * from ${schema}.task_identifiers where task_id = ${1} and position = ${p}) as i
                " )"
            last_position="${p}"
        done
        set_feature "${control_list}=( \${${control_list}[@]:$((last_position-first_position+1))} )"
    fi

}

call_features () {

    #local call_id="${1}"

    for p in $( sql "select position from ${schema}.call_features where call_id = ${1} order by position" )
    do
        set_feature "$( sql "select name || '=' || value from ${schema}.call_features where call_id = ${1} and position = ${p}" )"
    done

}

instance_id () {

    #local task_id="${1}"
    #local task_name="${2}"

    bash <<EOF
        $(
        put_features
        echo "${sql_client} <<EOF"
        echo "
            with
                src (name, identifier) as
                    (
                    select '${2}'::text, array[
            "
        sql "
            select
                case position
                    when 0
                    then ''
                    else ','
                end
            ||  case identifier_type_id
                    when 0 then '''\${' || name || '}'''
                    when 1 then '''( \${' || name || '[@]} )'''
                end
            from ${schema}.task_identifiers
            where task_id = ${1} and identifier_type_id < 2
            order by position
            "
        echo "
                        ]::text[]
                    )
            ,   upd (id) as
                    (
                    update ${schema}.instances
                    set active = true
                    where (name, identifier) in (select name, identifier from src)
                    returning id
                    )
            ,   ins (id) as
                    (
                    insert into ${schema}.instances (name, identifier, active)
                    select name, identifier, true
                    from src
                    where (name, identifier) not in (select name, identifier from ${schema}.instances)
                    returning id
                    )
            select id from upd
            union all
            select id from ins
            "
        echo "EOF"
        )
EOF

}

control_list_length () {

#local task_id="${1}"

bash <<EOF
$(put_features)
echo $(sql "select '\${#' || name || '[@]}' from ${schema}.task_identifiers where task_id = ${1} and identifier_type_id = 1")
EOF

}

instance_name () {

    local instance_id="${1}"
    local instance_name_prefix="${2}"
    local instance_name_length="${3}"

    echo "${instance_name_prefix}${instance_id}" | sed -e "s/\(0*\)\([[:digit:]]\{"${instance_name_length}","${instance_name_length}"\}\)/\2/"

}

task_name () {

    local call_id="${1}"

    bash <<EOF
        $(
        put_features
        sql "select 'echo ' || name from ${schema}.calls where id = ${call_id}"
        )
EOF

}

server () {

    local task_type="${1}"

    bash <<EOF
        $(
        put_features
        if [ "${task_type}" == "execute" ]
        then
            echo "
                if [ \"\${executor}\" != \"\" ]
                then
                    echo \"\${executor}\"
                else
                    echo \"ERROR: The feature 'executor' is not set!\" >&2
                fi
                "
        elif [ "${task_type}" == "generate" ]
        then
            echo "
                if [ \"\${generator}\" != \"\" ]
                then
                    echo \"\${generator}\"
                else
                    echo \"ERROR: The feature 'generator' is not set!\" >&2
                fi
                "
        fi
        )
EOF

}

server_type () {

    #local server="${1}"

    local server_location=$(find ./*/srv -name "${1}")
    case $(echo "${server_location}" | wc -w) in
    0)
        echo "ERROR: No directory '${PWD}/*/srv' contains the server file '${1}'!" >&2
        ;;
    1)
        echo ${server_location} | sed -e "s/^.*\/\(.*\)\/srv\/${1}/\1/"
        ;;
    *)
        echo "ERROR: Directories '${server_location}' contain the ambiguous server file '${1}'!" >&2
        ;;
    esac

}

get_env () {

    #local server_type="${1}"
    #local variable="${2}"

    local server_type_dir="${PWD}/${1}"
    local env_file="${server_type_dir}/bin/env"
    if [ -d ${server_type_dir} ]
    then
        if [ -e ${env_file} ]
        then
            grep -e "^[[:blank:]]*${2}=" "${env_file}" | sed -e "s/^[[:blank:]]*${2}=//"
        else
            echo "ERROR: The environment file 'env' does not exist in '${PWD}/${1:-"\${server_type}"}/bin' directory!" >&2
        fi
    else
        echo "ERROR: The directory for the server type '${1:-"\${server_type}"}' does not exist!" >&2
    fi

}

substitute_code () {

    #local task_name="${1}"
    #local task_type="${2}"
    #local instance_name="${3}"

    local server="$(server "${2}")"
    if [ "${server}" != "" ]
    then
        local server_type="$(server_type "${server}")"
        if [ "${server_type}" != "" ]
        then
            local sfx="$(get_env "${server_type}" "sfx")"
            if [ "${sfx}" != "" ]
            then
                local source_file_name="${PWD}/${server_type}/src/${1}.${sfx}"
                if [ -e "${source_file_name}" ]
                then
                    bash <<EOF
                        $(
                        put_features
                        echo "cat > \"${PWD}/${server_type}/${2:0:3}/${3}.${sfx}\" <<EOF"
                        cat "${source_file_name}"
                        echo "EOF"
                        )
EOF
                else
                    echo "ERROR: The source file '${source_file_name}' does not exist!" >&2
                fi
            fi
        fi
    fi

}

log_instance () {

    #local instance_id="${1}"
    #local instance_name="${2}"

    sql "select 'INSTANCE ${2} IS TASK ' || name || case when identifier <> array[]::text[] then ' IDENTIFIED BY ' || array_to_string(identifier, ' ') else '' end from ${schema}.instances where id = ${1}"

}

expand_tree () {

    #local parent_task_id="${1}"

    for call_id in $( sql "select call_id from ${schema}.call_leaves where dependent_task_id = ${1}" )
    do
        local task_name="$(task_name "${call_id}")"
        local task_id="$(sql "select id from ${schema}.tasks where name = '${task_name}'")"
        if [ "${task_id}" != "" ]
        then
            local task_type="$(sql "select tt.name from ${schema}.tasks as t inner join ${schema}.task_types as tt on tt.id = t.task_type_id where t.id = '${task_id}'")"
            if [ "$(control_list_length "${task_id}")" != "0" ]
            then
                set_feature "#"
                call_identifiers "${task_id}" "${call_id}"
                local instance_id="$(instance_id "${task_id}" "${task_name}")"
                local instance_name="$(instance_name "${instance_id}" "${instance_name_prefix}" "${instance_name_length}")"
                log_instance "${instance_id}" ${instance_name}
                control_list_features "${task_id}"
                task_features "${task_id}"
                call_features "${call_id}"
                if   [ "${task_type}" != "call" ]
                then
                    substitute_code "${task_name}" "${task_type}" "${instance_name}"
                fi
                expand_tree "${task_id}"
                unset_features
            fi
        else
            echo "ERROR: The task '${task_name}' does not exist!" >&2
        fi
    done
}

sql "update ${schema}.instances set active = false"

main_task_id=$(sql "select id from ${schema}.tasks where name = '${main_task_name}'")
feature=( "#" )
n=0
instance_id=$(instance_id "${main_task_id}" "${main_task_name}" "" "-1" "-1")
instance_name=$(instance_name "${instance_id}" "${instance_name_prefix}" "${instance_name_length}")
log_instance "${instance_id}" "${instance_name}"
task_features "${main_task_id}" "" "-1" "-1"

expand_tree "${main_task_id}"

exit 0

task_name="${main_task_name}"
instance_id=$( sql "
with
  upd (id) as
    (
    update ${schema}.instances
    set active = true
    where name = '${main_task_name}' and identifier = array[]::text[]
    returning id
    )
, ins (id) as
    (
    insert into ${schema}.instances (name, identifier, active)
    select '${main_task_name}', array[]::text[], true
    where not exists
      (
      select null
      from ${schema}.instances
      where name = '${main_task_name}' and identifier = array[]::text[]
      )
    returning id
    )
select id from upd
union all
select id from ins
" )

#while [ "${instance_id}" != "" ]
#do
instance_id=$(
bash <<EOF
$(
sql "
/* */
select tf.name||'='||tf.value
from ${schema}.tasks as t
inner join ${schema}.task_features as tf on tf.task_id = t.id
where t.name = '${task_name}'
order by tf.position
"
)
echo \${ScheduleDaily0000}
echo \${MaxTimeStamp}
echo \${pokus}
echo \${ExtPath}
EOF
)
echo ${instance_id}
#done
