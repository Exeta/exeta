export exeta_db=postgres
export exeta_schema=exeta
export exeta_user=martin
export EXETA_HOME=${HOME}/Exeta
if [[ "${PATH}" == "${PATH/${EXETA_HOME}\/bin/}" ]] ; then
    export PATH=${PATH}:${EXETA_HOME}/bin
fi
export EXETA_REP_QUERY="psql postgres -A -q -t -z -c"
