/* [busy_jobs.sql]
PURPOSE
	identify hotspots when several SQLAgent jobs all fire simultaneously
	
HISTORY
	20090325 dbaker	created

NOTES
1.	having peaks when several jobs are each scheduled for same kick-off is bad
- security authorisations to AD/DC may get lost (UDP) or delayed (hence login fails)
- spikes for CPU/memory/disk/network can deplete resource pools and cause retries/timeouts
2.  so although any decent system OUGHT to cope, real-world suggests that offset pragmatism is better
- up to DBAs to watch for hotspots, and fine-tune any such (even 10-second separation is enough)
*/
use msdb
go
select N=count(*), run_date, run_time
into #BUSY		-- drop table #BUSY
from
(	select	distinct run_date,run_time,job_id
	from	sysjobhistory
	where	step_id=1
) A
--where run_date >= 20090324
group by run_date, run_time
having count(*) > 5
order by N desc, run_time, run_date

-- thin to just recent occurences
delete from #BUSY
where exists(select 1 from #BUSY X where X.run_time=#BUSY.run_time and X.N <= #BUSY.N and X.run_date > #BUSY.run_date)

-- ignore any hotspot if solely caused by system restart, i.e. when SQLAgent runs [after reboot]
delete from #BUSY
where NOT exists
(	select	J.name
	from	sysjobhistory JH
	join	sysjobs J on J.job_id=JH.job_id
	join	sysjobschedules JS on J.job_id=JS.job_id
	join	sysschedules S on JS.schedule_id=S.schedule_id
	where	JH.run_date=#BUSY.run_date
	 and	JH.run_time=#BUSY.run_time
	 and	J.enabled=1
	 and	S.enabled=1
	 and	(S.freq_type & 64) = 0		-- 64 = Runs when the SQL Server Agent service starts
)

-- select * from #BUSY order by N desc, run_time, run_date

/*
select run_date,run_time,J.name,JH.job_id
from sysjobhistory JH
left join sysjobs J on J.job_id=JH.job_id
where run_date=20090324	-- 20090318	--20090321
 and run_time=180000	--192634	--123024
 and step_id=1
order by run_date, J.name
*/

select distinct B.N, JH.run_date,JH.run_time,J.name	--,JH.job_id
from sysjobhistory JH
left join sysjobs J on J.job_id=JH.job_id
join #BUSY B on B.run_date=JH.run_date and B.run_time=JH.run_time
where step_id=1
order by N desc, JH.run_time,JH.run_date, J.name