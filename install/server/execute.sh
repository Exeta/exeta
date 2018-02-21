#!/bin/bash

run_id=${1}

tsk_type=$(${EXETA_REP_QUERY} "select get_tsk_type(${run_id});")
calins_name=$(${EXETA_REP_QUERY} "select get_calins_name(${run_id});")

exe_name=$(${EXETA_REP_QUERY} "select get_exe_name(${run_id});")
exe_type=$(${EXETA_REP_QUERY} "select get_exe_type(${run_id});")
exe_addr=

# get features and run_ts
${EXETA_REP_QUERY} "select get_run_features(${run_id});" \
    > ${EXETA_HOME}/rep/${exe_type}/${exe_name}/tmp/${run_id}.par

# get call instance code
sub.sh \
    ${EXETA_HOME}/rep/${exe_type}/${exe_name}/tmp/${run_id}.par \
    ${EXETA_HOME}/rep/${exe_type}/${exe_name}/src/${calins_name} \
    > ${EXETA_HOME}/rep/${exe_type}/${exe_name}/tmp/${run_id}

if \
    [[ "${tsk_type}" == "EXECUTE" ]]
then
    src_dir="exe"
else
    src_dir="gen"
    if \
        [[  "${tsk_type}" == "GENERATE" \
        || ! -e ${EXETA_HOME}/rep/${exe_type}/${exe_name}/gen/${calins_name} \
        ]]
    then
        # generate
        gen_name=$(${EXETA_REP_QUERY} "select get_gen_name(${run_id});")
        gen_type=$(${EXETA_REP_QUERY} "select get_gen_type(${run_id});")
        gen_addr=$(${EXETA_REP_QUERY} "select get_gen_addr(${run_id});")
        scp \
            ${EXETA_HOME}/rep/${exe_type}/${exe_name}/tmp/${run_id} \
            exeta@${gen_addr}:~/rep/${gen_type}/${gen_name}/src
        ssh exeta@${gen_addr} -e ~/rep/${gen_type}/bin/gen.sh !!!!!!!!!!
    fi
fi

# get call instance code
cat ${EXETA_HOME}/rep/${exe_type}/${exe_name}/${src_dir}/${calins_name} > ${run_id}.src

# substitute code
./substitute ${run_id}.par ${run_id}.src > ${run_id}

# get ssh server address

# get executor's parameters

# copy substituted code onto the ssh server

# set status to RUNNING in the repository
${EXETA_REP_QUERY} "select set_run_status(${run_id}, 'RUNNING');"

# submit a run of copied substituted code on its executor on the ssh server (nohup ... &)
# and log pid

