create sequence wrk_area.party_s
;
create table tgt_layer.party
(   party_id    integer   not null
,   start_ts    timestamp not null
,   end_ts      timestamp not null
,   source_id   text      not null
,   name        text      not null
,   primary key (party_id, start_ts)
)
;
