task ProvideExtracts.CzSO
with Source = ${EXETA_TUTORIAL_HOME}/rmt/czso
  ,  Target = ${ExtPath}/czso
submit same after 10 m 3 times then skip when failed
submit next when succeeded
submit next when skipped
call Copy "${Source}/KLAS80004_CS.csv" "${Target}/KLAS80004_CS.${TimeStamp}.dat"
  || Copy "${Source}/RES_CS.csv"       "${Target}/RES_CS.${TimeStamp}.dat"
;

