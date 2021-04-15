/*
List Session and Scheduler ID Information

Description

Sample script that lists session_id, status, scheduler_id, statement, sql_handle, and plan_handle information. This script requires Microsoft SQL Server 2005. 

Script Code


*/

select 
	scheduler_id,
	current_tasks_count,
	runnable_tasks_count,
	current_workers_count,
	active_workers_count,
	work_queue_count,
	load_factor,
	status
from sys.dm_os_schedulers
--where scheduler_id < 255
order by scheduler_id

select r.session_id
		,status
		,wait_type
		,r.scheduler_id
		,substring(qt.text,r.statement_start_offset/2, 
			(case when r.statement_end_offset = -1 
			then len(convert(nvarchar(max), qt.text)) * 2 
			else r.statement_end_offset end -r.statement_start_offset)/2) 
		as stmt_executing
		,r.sql_handle
		,qt.dbid
		,qt.objectid
		,r.cpu_time
		,r.total_elapsed_time
		,r.reads
		,r.writes
		,r.logical_reads
		,r.plan_handle
from sys.dm_exec_requests r
cross apply sys.dm_exec_sql_text(sql_handle) as qt
where r.session_id > 50
order by r.scheduler_id, r.status, r.session_id

