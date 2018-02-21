create sequence wrk_area.activity_s
;
create table tgt_layer.activity
(   activity_id integer   not null
,   start_ts    timestamp not null
,   end_ts      timestamp not null
,   source_id   text      not null
,   name        text      not null
,   description text      not null
,   primary key (activity_id, start_ts)
)
;
