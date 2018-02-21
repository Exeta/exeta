create or replace PACKAGE PACK_ALF_PROC_CALENDAR IS

FUNCTION GETLISTELEMENT
 (S IN varchar2
 ,N IN integer
 ,D IN varchar2 := ','
 )
 RETURN INTEGER DETERMINISTIC;

FUNCTION GETLISTLENGTH
 (S IN varchar2
 ,D IN varchar2 := ','
 )
 RETURN INTEGER DETERMINISTIC;

FUNCTION GETNEXTTIME
 (YPROCNAME IN varchar2
 ,YDATE IN date := sysdate
 )
 RETURN DATE;

END PACK_ALF_PROC_CALENDAR;


create or replace PACKAGE BODY PACK_ALF_PROC_CALENDAR IS

FUNCTION GETLISTELEMENT
 (S IN varchar2
 ,N IN integer
 ,D IN varchar2 := ','
 )
 RETURN INTEGER
 IS

  i integer := instr(d || trim(s), d, 1, n) + 1;
begin
  return
    substr(
      d || trim(s),
      i,
      instr(d || trim(s) || d, d, 1, n + 1) - i
    )
  ;
end;

FUNCTION GETLISTLENGTH
 (S IN varchar2
 ,D IN varchar2 := ','
 )
 RETURN INTEGER
 IS
begin
  return length(translate(d || trim(s), d || '0123456789', d));
end;

FUNCTION GETNEXTTIME
 (YPROCNAME IN varchar2
 ,YDATE IN date := sysdate
 )
 RETURN DATE
 IS

  xRes  date;
begin
  select
    min(to_date(to_char(dt, 'yyyymmdd') || hh24.hour || mi.minute, 'yyyymmddhh24mi'))
  into
    xRes
  from
    (
    select
	  seq,
	  dt,
	  rnk
    from
      (
      select
	    mm.seq,
		j.dt,
        rank() over (partition by mm.seq order by j.dt) as rnk
      from
        (
        /* generate all dates from yDate to the end of the next year */
        select     to_date(level - 1 + to_char(yDate, 'j'), 'j') as dt
        from       dual
        connect by level <= to_char(to_date(to_char(yDate, 'yyyy') + 1 || '1231', 'yyyymmdd'), 'j') - to_char(yDate, 'j') + 1
        ) j,
        (
        /* generate day of month rows - one row for each day from the list in the day_of_month column */
        select     seq, lpad(GetListElement(day_of_month, x), 2, '0') as day_of_month
        from       alf_proc_calendar,
		  (
		  select     level as x
		  from       dual
		  connect by level <= (select max(GetListLength(day_of_month)) from alf_proc_calendar where procname = yProcName and trim(day_of_month) <> '*')
		  )
        where      procname = yProcName and trim(day_of_month) <> '*' and x <= GetListLength(day_of_month)
        union
        /* generate day of month rows - one row for each legal day of month (01-31) when day_of_month column contains '*' */
        select     seq, x as day_of_month
        from       alf_proc_calendar,
		  (
		  select     trim(to_char(level, '09')) as x
		  from       dual
          connect by level <= 31
		  )
        where      procname = yProcName and trim(day_of_month) = '*'
        ) dd,
        (
        /* generate day of week rows - one row for each day from the list in the day_of_week column */
        select     seq, GetListElement(day_of_week, x) as day_of_week
        from       alf_proc_calendar,
		  (
		  select     level as x
		  from       dual
		  connect by level <= (select max(GetListLength(day_of_week)) from alf_proc_calendar where procname = yProcName and trim(day_of_week) <> '*')
		  )
        where      procname = yProcName and trim(day_of_week) <> '*' and x <= GetListLength(day_of_week)
        union
        /* generate day of week rows - one row for each legal day of week (01-07) when day_of_week column contains '*' */
        select     seq, x as day_of_week
        from       alf_proc_calendar,
		  (
		  select    level as x
		  from      dual
          connect by level <= 7
		  )
        where      procname = yProcName and trim(day_of_week) = '*'
        ) d,
        (
        /* generate month of year rows - one row for each month from the list in the month_of_year column */
        select     seq, lpad(GetListElement(month_of_year, x), 2, '0') as month_of_year
        from       alf_proc_calendar,
		  (
		  select     level as x
		  from       dual
		  connect by level <= (select max(GetListLength(month_of_year)) from alf_proc_calendar where procname = yProcName and trim(month_of_year) <> '*')
		  )
        where      procname = yProcName and trim(month_of_year) <> '*' and x <= GetListLength(month_of_year)
        union
        /* generate month of year rows - one row for each legal month of year (01-12) when month_of_year column contains '*' */
        select     seq, x as month_of_year
        from       alf_proc_calendar,
		  (
		  select    trim(to_char(level, '09')) as x
		  from      dual
          connect by level <= 12
		  )
        where      procname = yProcName and trim(month_of_year) = '*'
        ) mm
      where
        mm.seq = dd.seq
		and
		mm.seq = d.seq
        and
        mm.month_of_year = to_char(j.dt, 'mm')
        and
        ( dd.day_of_month = to_char(j.dt, 'dd') or dd.day_of_month = '32' and j.dt = last_day(j.dt) )
        and
        d.day_of_week = to_char(j.dt, 'd')
      order by
        j.dt
      )
    where
      rnk <= 2
    ) d,
    (
	/* generate minute rows - one row for each minute from the list in the minute column */
    select     seq, lpad(GetListElement(minute, x), 2, '0') as minute
    from       alf_proc_calendar,
	  (
	  select     level as x
	  from       dual
	  connect by level <= (select max(GetListLength(minute)) from alf_proc_calendar where procname = yProcName and trim(minute) <> '*')
	  )
    where      procname = yProcName and trim(minute) <> '*' and x <= GetListLength(minute)
    union
	/* generate minute rows - one row for each legal minute (00-59) when minute column contains '*' */
    select     seq, x as minute
    from       alf_proc_calendar,
	  (
	  select    trim(to_char(level - 1, '09')) as x
	  from      dual
      connect by level <= 60
	  )
    where      procname = yProcName and trim(minute) = '*'
    ) mi,
    (
	/* generate hour rows - one row for each hour from the list in the hour column */
    select     seq, lpad(GetListElement(hour, x), 2, '0') as hour
    from       alf_proc_calendar,
	  (
	  select     level as x
	  from       dual
	  connect by level <= (select max(GetListLength(hour)) from alf_proc_calendar where procname = yProcName and trim(hour) <> '*')
	  )
    where      procname = yProcName and trim(hour) <> '*' and x <= GetListLength(hour)
    union
	/* generate hour rows - one row for each legal hour (00-23) when hour column contains '*' */
    select     seq, x as hour
    from       alf_proc_calendar,
	  (
	  select    trim(to_char(level - 1, '09')) as x
	  from      dual
      connect by level <= 24
	  )
    where      procname = yProcName and trim(hour) = '*'
    ) hh24
  where
    d.seq = mi.seq
    and
    d.seq = hh24.seq
	and
	yDate < to_date(to_char(dt, 'yyyymmdd') || hh24.hour || mi.minute, 'yyyymmddhh24mi')
  ;
  return xRes;
end;
end;

