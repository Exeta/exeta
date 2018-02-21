#!/bin/bash

export run_id=$1

EXETA_REP_QUERY="psql postgres -A -q -t -z -c"

exe_name=$(${EXETA_REP_QUERY} "select get_exe_name(${run_id});")
ins_name=$(${EXETA_REP_QUERY} "select get_exeins_name(${run_id});")
#run_ts=$(${EXETA_REP_QUERY} "select get_run_ts(${run_id});")

exe_path=${EXETA_HOME}/rep/${exe_name}
exe_file=${exe_path}/exe/wrapper.sh
##ins_par_file=${exe_path}/exe/${ins_name}.par
##ins_con_file=${exe_path}/exe/${ins_name}.con
mod_file=${exe_path}/mod/$(${EXETA_REP_QUERY} "select get_mod_name(${run_id});")
run_file=${exe_path}/wrk/$(${EXETA_REP_QUERY} "select get_calins_name(${run_id});")

# CREATE SCRIPT

touch ${run_file}.sh
chmod 700 ${run_file}.sh

# set call instance features
${EXETA_REP_QUERY} "select get_calins_features(${run_id});" > ${run_file}.sh
## set executor instance parameters
#if [[ -e ${ins_par_file} ]] ; then cat ${ins_par_file}  >> ${run_file}.sh ; fi
## set connection parameters
#if [[ -e ${ins_con_file} ]] ; then cat ${ins_con_file}  >> ${run_file}.sh ; fi
echo "cat >${run_file} <<EOF" >> ${run_file}.sh
cat ${mod_file} >> ${run_file}.sh
echo "EOF" >> ${run_file}.sh

${run_file}.sh

#rm ${run_file}.sh

# SUBMIT JOB

#scp -i ~/.ssh/id_rsa ${run_file} exeta@localhost:~
#ssh -i ~/.ssh/id_rsa exeta@localhost <<SSH
nohup ${exe_file} ${run_id} ${run_file} EXECUTE >${run_file}.log 2>&1 &
#SSH
