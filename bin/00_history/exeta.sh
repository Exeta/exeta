#!/bin/bash

set -e

trap "rm -f .exeta_lock ; exit 1" ERR SIGKILL SIGHUP SIGINT SIGTERM

# setup exeta environment variables

. exeta_env.sh

cd ${exeta_directory}

# check if previous exeta job execution is still running

if [ -e .exeta_lock ] ; then
    exit 1
fi

# no exeta job is currently running - acquire the lock

touch .exeta_lock

# update status of all runs in status 'RUNNING'
# submit new runs for succeeded ones
# TODO

psql --quiet --tuples-only --no-align --command="\
select 'run_id='||run_id||' ; run_ts=\"'||run_ts||'\" ; task_id='||task_id \
from ${exeta_schema}.run_candidates" \
${exeta_db} ${exeta_user} > exeta_task_list
        
# submit all enabled task runs with regard to their importance

while read task ; do
    
    # set task variables
    
    eval $( ${task} )
    
    # update status of the task run to 'RUNNING'
    
    psql --quiet --tuples-only --command="\
update ${exeta_schema}.runs \
set \
    restart_cnt = case status_id when ${exeta_schema}.get_run_status_id('FAILED') then restart_cnt + 1 else 0 end, \
    last_restart_ts = case status_id when ${exeta_schema}.get_run_status_id('FAILED') then current_timestamp end, \
    status_id = ${exeta_schema}.get_run_status_id('RUNNING') \
where run_id = ${run_id}" \
        ${exeta_db} ${exeta_user}
    
    # submit task run
    
    exec_task.sh ${run_id}    
    
done < exeta_task_list

# release the exeta lock

rm -f .exeta_lock

