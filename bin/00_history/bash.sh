#!/bin/bash

# parameters

calins_id=${1}
run_ts=${2}

# create log

touch ${calins_id}_${run_ts}.RUNNING

# execute task

$(< cat ${calins_id}_${run_ts})

# log result

if [ $? -eq 0 ] ; then
    mv \
        ${calins_id}_${run_ts}.RUNNING \
        ${calins_id}_${run_ts}.SUCCEEDED
else
    mv \
        ${calins_id}_${run_ts}.RUNNING \
        ${calins_id}_${run_ts}.FAILED
fi
