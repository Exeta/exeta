create table ${StgSchema}.${Table}_\${TimeStamp[YYYYMMDDHH24MISS]}
(   _load_id bigint not null default \${TimeStamp[YYYYMMDDHH24MISS]}
)
inherits (${StgSchema}.${Table})
;
