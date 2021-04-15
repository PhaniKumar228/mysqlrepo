/*
which scheduled jobs failed on their last run?

Uses the sysjobs and the sysjobhistory tables in the msdb database to determine if ONLY THE MOST RECENT RUN of any job on the server failed. 

*/

use master
go
CREATE procedure sp_jobfails as 
select N'(Stm-testdb) Last execution failed on ' + 
	substring(convert(nchar(8),sjh.run_date),5,2) + '/' +
	substring(convert(nchar(8),sjh.run_date),7,2) + N' at ' +
	convert(nvarchar(12),sjh.run_time) + ' for job: ' + sj.[name] 
from 
	msdb..sysjobs sj
inner join
	msdb..sysjobhistory sjh
on 
	sj.job_id = sjh.job_id
inner join (select job_id, max(instance_id) as ins_id
		from msdb..sysjobhistory
		group by job_id) q
on
	sjh.instance_id = q.ins_id
and
	sjh.run_status = 0
GO

-- can be called from any database on the server since it begins with "sp_" and lives in the master database.
