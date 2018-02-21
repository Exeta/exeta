task LoadStgLayer
with Retention = 14
  ,  Encoding = UTF8
call LoadStgLayer.CzSO
;

task LoadStgLayer.CzSO
with Source = czso
  ,  Retention = 7
  ,  Encoding = WIN1250
call LoadStgTable ${Source}_KLAS80004_CS
       with Extract = KLAS80004_CS
  || LoadStgTable ${Source}_RES_CS
       with Extract = RES_CS
;
