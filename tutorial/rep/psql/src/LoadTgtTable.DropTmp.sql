select 'drop table ${WrkSchema}.' || c.relname || ';'
from pg_namespace as n
inner join pg_class as c on c.relowner = n.nspowner
where n.nspname = '${WrkSchema}' and c.relname similar to '${Table}+_[Tt][0-9]{2,2}' escape '+'
; 
