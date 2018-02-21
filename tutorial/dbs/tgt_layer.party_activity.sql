create table tgt_layer.party_activity
(   party_id    integer   not null
,   order_num   integer   not null
,   activity_id integer   not null
,   start_ts    timestamp not null
,   end_ts      timestamp not null
,   primary key (party_id, order_num, activity_id, start_ts)
)
;
