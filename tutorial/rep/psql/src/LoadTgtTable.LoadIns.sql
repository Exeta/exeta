insert into ${TgtSchema}.${Table}
select * from ${WrkSchema}.${Table}_i
union all
select * from ${WrkSchema}.${Table}_u
;
