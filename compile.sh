#!/bin/bash

set -e

in_file=${1}
log_file=${in_file%.e}.log

exeta <${in_file} 2>${log_file}
psql postgres -f ${EXETA_HOME}/bin/delete_interface.sql
bash ${EXETA_HOME}/bin/load_interface.sh
bash ${EXETA_HOME}/bin/load_derived.sh
bash ${EXETA_HOME}/bin/load_permanent.sh

rm \
    ${log_file} \
    task.dsv \
    call.dsv \
    identifier_name.dsv \
    identifier_value.dsv \
    feature.dsv \
    rule.dsv \
    call_node.dsv \
    condition_node.dsv

exit 0

