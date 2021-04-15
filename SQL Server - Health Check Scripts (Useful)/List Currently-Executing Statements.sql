/*
List Currently-Executing Statements

Description

Sample script that lists currently-executing statements. A status equal to runnable indicates that the user waiting on the CPU. Note that each scheduler has its own runnable queue. This script, contributed by Microsoft's Tom Davidson, requires SQL Server 2005. 

Script Code


*/

select r.session_id
		,status
		,substring(qt.text,r.statement_start_offset/2, 
			(case when r.statement_end_offset = -1 
			then len(convert(nvarchar(max), qt.text)) * 2 
			else r.statement_end_offset end - r.statement_start_offset)/2) 
		as query_text   --- this is the statement executing right now
		,qt.dbid
		,qt.objectid
		,r.cpu_time
		,r.total_elapsed_time
		,r.reads
		,r.writes
		,r.logical_reads
		,r.scheduler_id
from sys.dm_exec_requests r
cross apply sys.dm_exec_sql_text(sql_handle) as qt
where r.session_id > 50
order by r.scheduler_id, r.status, r.session_id

