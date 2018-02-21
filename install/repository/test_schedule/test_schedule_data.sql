insert into p_schedule (id, position, schedule_type_id, value) values
    (1, 1, 1,  0)
,   (1, 1, 1, 15)
,   (1, 1, 1, 45)
;
insert into p_schedule (id, position, schedule_type_id, value) values
    (1, 1, 2,  0)
,   (1, 1, 2,  1)
,   (1, 1, 2,  2)
,   (1, 1, 2, 18)
;
insert into p_schedule (id, position, schedule_type_id, value) values
    (1, 1, 3, 15)
;
insert into p_schedule (id, position, schedule_type_id, value) values
    (1, 1, 4, -15)
,   (1, 1, 4,   0)
;
insert into p_schedule (id, position, schedule_type_id, value) values
    (1, 1, 5,  1)
,   (1, 1, 5,  2)
,   (1, 1, 5,  3)
,   (1, 1, 5,  4)
,   (1, 1, 5,  5)
,   (1, 1, 5,  6)
,   (1, 1, 5,  7)
,   (1, 1, 5,  8)
,   (1, 1, 5,  9)
,   (1, 1, 5, 10)
,   (1, 1, 5, 11)
,   (1, 1, 5, 12)
;
insert into p_schedule (id, position, schedule_type_id, value) values
    (1, 1, 6, 1)
,   (1, 1, 6, 2)
,   (1, 1, 6, 3)
,   (1, 1, 6, 4)
,   (1, 1, 6, 5)
,   (1, 1, 6, 6)
,   (1, 1, 6, 7)
;

select * from f_schedule_timestamp(1, timestamp '2017-12-15 18:00:00', +1, false) ;
/*
 f_schedule_timestamp 
----------------------
 2017-12-15 18:15:00
(1 row)
*/
select * from f_schedule_timestamp(1, timestamp '2017-12-15 16:00:00', +1, false) ;
/*
 f_schedule_timestamp 
----------------------
 2017-12-15 18:00:00
(1 row)
*/
select * from f_schedule_timestamp(1, timestamp '2017-12-15 18:00:00', -1, true) ;
/*
 f_schedule_timestamp 
----------------------
 2017-12-15 18:00:00
(1 row)
*/
select * from f_schedule_timestamp(1, timestamp '2017-12-15 18:00:00', -1, false) ;
/*
 f_schedule_timestamp 
----------------------
 2017-12-15 02:45:00
(1 row)
*/

