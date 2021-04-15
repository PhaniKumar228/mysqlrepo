/*

Job Run Duration

This script gives you an idea on how long the processing time is for your SQL jobs. 
It will depend on how many records are being retained on the sysjobhistory table (scripts defaults to the last 30 days--may not find any history at all).
One may find it useful when there are so many sql jobs and need to find some stats. 
More useful when combined with List SQL Server Jobs scripts.

Below are the returned column with a little explanation:
  Job Name    --  Name of the Scheduled Job
  Last_RunDate -- Last execution datetime
  Last_RunStatus -- status for the last run
  Last_RunDuration -- format is hh:mm:ss
  Avg Duration -- average exec time; format in hh:mm:ss
  Max Duration -- maximum exec time; format in hh:mm:ss
  Min Duration -- minimum exec time; format in hh:mm:ss
  From Date    -- oldest job run sampled 
  Sampling     -- number of job history collected (run 
                  status doesnt matter)

*/

set nocount on
go
use msdb
go
declare @num_days int
declare @first_day datetime
	,@last_day datetime
declare @first_num int

if @num_days is null
	set @num_days=30

set @last_day = getdate()
set @first_day = dateadd(dd, -@num_days, @last_day)

select @first_num= cast(year(@first_day) as char(4))
	+replicate('0',2-len(month(@first_day)))+ cast(month(@first_day) as varchar(2))
	+replicate('0',2-len(day(@first_day)))+ cast(day(@first_day) as varchar(2))

select
h.instance_id,
h.job_id,
j.name,
h.step_id,
h.step_name,  		--extra
h.sql_message_id,	--extra
h.sql_severity,		--extra
h.run_status,		--extra
'run_date'= cast(h.run_date as varchar(8)),		
'run_time'= replicate('0',6-len(h.run_time))+cast(h.run_time as varchar(6)),
'run_datetime' = left(cast(h.run_date as varchar(8)),4)+'/'
		+substring(cast(h.run_date as varchar(8)),5,2)+'/'
		+right(cast(h.run_date as varchar(8)),2)+' '
		+left(replicate('0',6-len(h.run_time))+cast(h.run_time as varchar(6)),2)+':'
		+substring(replicate('0',6-len(h.run_time))+cast(h.run_time as varchar(6)),3,2)+':'
		+right(replicate('0',6-len(h.run_time))+cast(h.run_time as varchar(6)),2),
run_duration = cast(h.run_duration as varchar(20)),
run_duration_conv = case 
	when (len(cast(h.run_duration as varchar(20))) < 3)  
		then cast(h.run_duration as varchar(6))
	WHEN (len(cast(h.run_duration as varchar(20))) = 3)  
		then LEFT(cast(h.run_duration as varchar(6)),1) * 60   --min
			+ RIGHT(cast(h.run_duration as varchar(6)),2)  --sec
	WHEN (len(cast(h.run_duration as varchar(20))) = 4)  
		then LEFT(cast(h.run_duration as varchar(6)),2) * 60   --min
			+ RIGHT(cast(h.run_duration as varchar(6)),2)  --sec
	WHEN (len(cast(h.run_duration as varchar(20))) >= 5)  
		then (Left(cast(h.run_duration as varchar(20)),len(h.run_duration)-4)) * 3600   		--hour
			+(substring(cast(h.run_duration as varchar(20)) , len(h.run_duration)-3, 2)) * 60	--min
			+ Right(cast(h.run_duration as varchar(20)) , 2)					--sec
	end,
h.retries_attempted,
h.server
into #temp_jobhistory
from msdb..sysjobhistory h, msdb..sysjobs j
where 	h.job_id=j.job_id 
	and h.run_date >= @first_num
	and h.step_id=0

select j.job_id
	,j.name
	,'Sampling'=(select count(*) from #temp_jobhistory h where h.job_id=j.job_id)
	,'fromRunDate' = (select min(run_date) from #temp_jobhistory h where h.job_id=j.job_id)
	,'run_duration_max'=(select max(run_duration_conv) from #temp_jobhistory h where h.job_id=j.job_id)
	,'run_duration_min'=(select min(run_duration_conv) from #temp_jobhistory h where h.job_id=j.job_id)
	,'run_duration_avg'=(select avg(run_duration_conv) from #temp_jobhistory h where h.job_id=j.job_id)
	,'Last_RunDate'=(select max(run_datetime) from #temp_jobhistory h where h.job_id=j.job_id)
	,'Last_RunStatus'= null --(select run_status from #temp_jobhistory h where h.job_id=j.job_id)
	,'Last_RunDuration'=null
into #temp_runhistory
	from msdb..sysjobs j


update #temp_runhistory 
set Last_RunStatus = j.run_status
	,Last_RunDuration=j.run_duration_conv
from #temp_jobhistory j
where #temp_runhistory.job_id=j.job_id
	and #temp_runhistory.Last_RunDate=j.run_datetime
	and j.run_datetime=(select max(run_datetime) from #temp_jobhistory j1
				where j1.job_id=#temp_runhistory.job_id)

select name as 'Job Name',
	Last_RunDate,
	'Last_RunStatus'=case Last_RunStatus
				when 0 then 'Failed'
				when 1 then 'Succeeded'
				when 2 then 'Retry'
				when 3 then 'Canceled'
				when 4 then 'In progress'
			end,
	'Last_RunDuration'= cast(Last_RunDuration/3600 as varchar(10))
				+':'+replicate('0',2-len((Last_RunDuration % 3600)/60))+cast((Last_RunDuration % 3600)/60 as varchar(2))
				+':'+replicate('0',2-len((Last_RunDuration % 3600) %60))+cast((Last_RunDuration % 3600)%60 as varchar(2)),
	'Avg Duration (hh:mm:ss)' = cast(run_duration_avg/3600 as varchar(10))
				+':'+replicate('0',2-len((run_duration_avg % 3600)/60))+cast((run_duration_avg % 3600)/60 as varchar(2))
				+':'+replicate('0',2-len((run_duration_avg % 3600) %60))+cast((run_duration_avg % 3600)%60 as varchar(2)),
	'Max Duration (hh:mm:ss)' = cast(run_duration_max/3600 as varchar(10))
				+':'+replicate('0',2-len((run_duration_max % 3600)/60))+cast((run_duration_max % 3600)/60 as varchar(2))
				+':'+replicate('0',2-len((run_duration_max % 3600) %60))+cast((run_duration_max % 3600)%60 as varchar(2)),
	'Min Duration (hh:mm:ss)' = cast(run_duration_min/3600 as varchar(10))
				+':'+replicate('0',2-len((run_duration_min % 3600)/60))+cast((run_duration_min % 3600)/60 as varchar(2))
				+':'+replicate('0',2-len((run_duration_min % 3600) %60))+cast((run_duration_min % 3600)%60 as varchar(2)),
	fromRunDate as 'From Date'
	,Sampling
 from #temp_runhistory
order by name

drop table #temp_runhistory
drop table #temp_jobhistory


