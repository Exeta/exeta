#!/bin/bash

set -e
#set -x

sql_client="psql postgres --tuples-only --no-align --quiet"
schema="exeta"
main_task_name="main"
instance_name_length=8
instance_name_prefix=$(for (( i=0 ; i<instance_name_length ; i++ )) ; do echo -n "0" ; done)
n=0
instance_id=-1
file_id=-1

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

    #local statement="${1}"

    ${sql_client} <<EOF
${1}
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

    for p in $(sql "select position from ${schema}.i_feature where task_id = ${1} and call_id is null order by position")
    do
        set_feature "$(sql "select name || '=' || value from ${schema}.i_feature where task_id = ${1} and call_id is null and position = ${p}")"
    done

}

call_features () {

    #local task_id=${1}
    #local call_id=${2}

    for p in $(sql "select position from ${schema}.i_feature where task_id = ${1} and call_id = ${2} order by position")
    do
        set_feature "$(sql "select name || '=' || value from ${schema}.i_feature where task_id = ${1} and call_id = ${2} and position = ${p}")"
    done

}

substitute () {

    #local command=${1}

    bash <<EOF
$(put_features)
${1}
EOF

}

call_identifiers () {

    #local parent_task_id="${1}"
    #local call_id="${2}"
    #local task_id="${3}"

    local pp=-1
    local name=
    local value=
    for p in $(sql "select position from ${schema}.i_identifier_value where task_id = ${1} and call_id = ${2} order by position")
    do
        name="$(sql "select name from ${schema}.i_identifier_name where task_id = ${3} and position = ${p}")"
        value="$(sql "select value from ${schema}.i_identifier_value where task_id = ${1} and call_id = ${2} and position = ${p}")"
        #echo task_id=${1} call_id=${2} name=${name} value=${value}
        feature[n+p]="${name}='$(substitute "echo ${value}")'"
        pp=${p}
    done
    n=$((n+pp+1))

}

control_list_features () {

    #local task_id="${1}"

    local control_list="$(sql "select name from ${schema}.i_identifier_name where task_id = ${1} and identifier_type_id = 1")"
    if [ "${control_list}" != "" ]
    then
        local first_position="$(sql "select position + 1 from ${schema}.i_identifier_name where task_id = ${1} and identifier_type_id = 1")"
        local last_position=""
        for p in $(sql "select position from ${schema}.i_identifier_name where task_id = ${1} and identifier_type_id = 2 order by position")
        do
            set_feature "$( sql "
                select name || '=\${${control_list}[$((p-first_position))]}'
                from (select * from ${schema}.i_identifier_name where task_id = ${1} and position = ${p}) as i
                " )"
            last_position="${p}"
        done
        set_feature "${control_list}=( \${${control_list}[@]:$((last_position-first_position+1))} )"
    fi

}

features () {
    
    local m=${n}
    local name=
    local value=
    for (( i=0 ; i<m ; i++ ))
    do
        n=$((i+1))
        name="${feature[i]%=*}"
        if [ "${name}" != "#" ]
        then
            #value="$(echo "$(substitute "echo \${${name}}")" | sed -e "s/'/''/g")"
            value="$(echo "$(substitute "declare -p ${name}")" | sed -e "s/'/''/g")"
            #echo "${name}=\"${value}\""
            sql "update ${schema}.d_feature set value='${value}' where instance_id = ${instance_id} and name = '${name}'"
            sql "insert into ${schema}.d_feature (instance_id, name, value) select ${instance_id}, '${name}', '${value}' where not exists (select null from ${schema}.d_feature where instance_id = ${instance_id} and name = '${name}')"
        fi
    done
}

instance () {
    
    #local parent_instance_id=${1}
    #local call_id=${2}
    #local task_id=${3}

    instance_id=$((instance_id+1))

    substitute "${sql_client} <<SQL
insert into ${schema}.d_instance (id, parent_id, call_id, task_id, identifier)
values
(   ${instance_id}, ${1}, ${2}, ${3}, array[$(sql "select case position when 0 then '' else ',' end || case identifier_type_id when 0 then '''\${' || name || '}''' when 1 then '''( \${' || name || '[@]} )''' end from ${schema}.i_identifier_name where task_id = ${3} and identifier_type_id < 2 order by position")]::text[]
)
SQL
"

}

control_list_length () {

    #local task_id="${1}"
    substitute "echo \"$(sql "select '\${#' || name || '[@]}' from ${schema}.i_identifier_name where task_id = ${1} and identifier_type_id = 1")\""

}

file_name () {

    #local file_id="${1}"

    echo "${instance_name_prefix}${1}" | sed -e "s/\(0*\)\([[:digit:]]\{"${instance_name_length}","${instance_name_length}"\}\)/\2/"

}

server () {

    #local task_type="${1}"

    substitute "$(
    if [ "${1}" == "execute" ]
    then
        echo "
            if [ \"\${executor}\" != \"\" ]
            then
                echo \"\${executor}\"
            else
                echo \"ERROR: The feature 'executor' is not set!\" >&2
            fi
            "
    else
        echo "
            if [ \"\${generator}\" != \"\" ]
            then
                echo \"\${generator}\"
            else
                echo \"ERROR: The feature 'generator' is not set!\" >&2
            fi
            "
    fi
    )"

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

substitute_source_file () {

    #local source_file_name="${1}"
    #local target_file_name="${2}"

    substitute "cat > \"${2}\" <<EOF
$(cat "${1}")
EOF"

}

substitute_code () {

    #local task_name="${1}"

    features

    local task_type="$(task_type "${task_id}")"
    echo "    task type ${task_type}"
    if   [ "${task_type}" == "call" ] ; then return ; fi
    
    local server="$(server "${task_type}")"
    if [ "${server}" == "" ] ; then return ; fi
    
    local server_type="$(server_type "${server}")"
    if [ "${server_type}" == "" ] ; then return ; fi
    
    local sfx="$(get_env "${server_type}" "sfx")"
    if [ "${sfx}" == "" ] ; then return ; fi
    
    file_id=$((file_id+1))
    local source_file_name="${PWD}/${server_type}/src/${1}.${sfx}"
    local target_file_name="${PWD}/${server_type}/${task_type:0:3}/$(file_name ${file_id}).${sfx}"
    if [ -e "${source_file_name}" ]
    then
        substitute_source_file "${source_file_name}" "${target_file_name}" 
        if [ "${task_type}" == "generate once" ]
        then
            local gen_script="${PWD}/${server_type}/bin/gen"
            local server="$(server execute)"
            if [ "${server}" == "" ] ; then return ; fi
            local server_type="$(server_type "${server}")"
            if [ "${server_type}" == "" ] ; then return ; fi
            local sfx="$(get_env "${server_type}" "sfx")"
            if [ "${sfx}" == "" ] ; then return ; fi
            local executable_file_name="${PWD}/${server_type}/exe/$(file_name ${file_id}).${sfx}"
            bash "${gen_script}" "${target_file_name}" "${executable_file_name}"
            sql "insert into ${schema}.d_file (instance_id, name) values (${instance_id}, '${executable_file_name}')"
        else
            sql "insert into ${schema}.d_file (instance_id, name) values (${instance_id}, '${target_file_name}')"
        fi
    else
        echo "ERROR: The source file '${source_file_name}' does not exist!" >&2
    fi

}

task_name () {

    #local task_id=${1}
    #local call_id=${2}
    substitute "echo $(sql "select name from ${schema}.i_call where task_id = ${1} and id = ${2}")"

}

task_id () {

    #local task_name="${1}"
    sql "select id from ${schema}.i_task where name = '${1}'"

}

task_type () {

    #local task_id=${1}
    sql "select name from ${schema}.r_task_type where id = (select task_type_id from ${schema}.i_task where id = ${1})"

}

task_condition_instances () {

    #local task_id="${1}"

    for call_id in $(sql "select condition_call_id from ${schema}.i_condition_node where task_id = ${1} and call_id is null and condition_node_type_id = 2")
    do
        local task_name="$(task_name "${1}" "${call_id}")"
        local task_id="$(task_id "${task_name}")"
        if [ "${task_id}" != "" ]
        then
            substitute "${sql_client} <<SQL
insert into ${schema}.d_condition (instance_id, call_id, task_id, identifier)
values
(   ${instance_id}, ${call_id}, ${task_id}, array[$(sql "select case position when 0 then '' else ',' end || '''' || value || '''' from ${schema}.i_identifier_value where task_id = ${1} and call_id = ${call_id} order by position")]::text[]
)
SQL"
        else
            echo "ERROR: The task '${task_name}' does not exist!" >&2
        fi
    done
}

call_condition_instances () {

    #local task_id="${1}"
    #local call_id="${2}"

    for call_id in $(sql "select condition_call_id from ${schema}.i_condition_node where task_id = ${1} and call_id = ${2} and condition_node_type_id = 2")
    do
        local task_name="$(task_name "${1}" "${call_id}")"
        local task_id="$(task_id "${task_name}")"
        if [ "${task_id}" != "" ]
        then
            substitute "${sql_client} <<SQL
insert into ${schema}.d_condition (instance_id, call_id, task_id, identifier)
values
(   ${instance_id}, ${call_id}, ${task_id}, array[$(sql "select case position when 0 then '' else ',' end || '''' || value || '''' from ${schema}.i_identifier_value where task_id = ${1} and call_id = ${call_id} order by position")]::text[]
)
SQL"
        else
            echo "ERROR: The task '${task_name}' does not exist!" >&2
        fi
    done
}

log_instance () {
    sql "select 'INSTANCE '||i.id||': '||t.name||' '||array_to_string(i.identifier, ' ') from ${schema}.d_instance as i inner join ${schema}.i_task as t on t.id = i.task_id where i.id = ${instance_id}"
}

expand_tree () {

    #local parent_task_id="${1}"
    #local parent_instance_id="${2}"

    for call_id in $(sql "select call_id from ${schema}.i_call_node where task_id = ${1} and call_node_type_id = 2")
    do
        local task_name="$(task_name "${1}" "${call_id}")"
        local task_id="$(task_id "${task_name}")"
        if [ "${task_id}" != "" ]
        then
            if [ "$(control_list_length "${task_id}")" != "0" ]
            then
                set_feature "#"
                call_identifiers "${1}" "${call_id}" "${task_id}"
                instance "${2}" "${call_id}" "${task_id}"
                log_instance
                control_list_features "${task_id}"
                task_features "${task_id}"
                task_condition_instances "${1}"
                call_features "${1}" "${call_id}" 
                call_condition_instances "${1}" "${call_id}"
                substitute_code "${task_name}"
                expand_tree "${task_id}" "${instance_id}"
                unset_features
            fi
        else
            echo "ERROR: The task '${task_name}' does not exist!" >&2
        fi
    done
}

#sql "update ${schema}.p_instance set active = false"

task_id="$(task_id "${main_task_name}")"
instance "null::integer" "null::integer" "${task_id}"
log_instance
task_features "${task_id}"
task_condition_instances "${task_id}"
substitute_code "${task_name}"
expand_tree "${task_id}" "${instance_id}"

exit 0

# zmenit feature na lokalni promennou obsahujici jedinecne, jiz substituovane promenne
# predelat pristupy do databaze v ramci jednoho volani procedury expand_tree na jeden (resp. nekolik, pokud nepujde jen jeden) bulk pristup do databaze
# dalsi varianta: pouzit perl s kurzory
