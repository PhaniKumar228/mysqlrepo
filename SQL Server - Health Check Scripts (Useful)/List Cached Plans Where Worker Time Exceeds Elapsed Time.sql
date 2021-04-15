/*
List Cached Plans Where Worker Time Exceeds Elapsed Time

Description

Sample script that finds cached plans that have a worker time greater than their elapsed time. When parallelism is used, (multiple) worker time will exceed clock (elapsed) time. This script, contributed by Microsoft's Tom Davidson, requires SQL Server 2005. 

Script Code


*/

select r.session_id,
	r.request_id,
	max(isnull(exec_context_id, 0)) as number_of_workers,
	r.sql_handle,
	r.statement_start_offset,
	r.statement_end_offset,
	r.plan_handle
from sys.dm_exec_requests r
	join sys.dm_os_tasks t on r.session_id = t.session_id
	join sys.dm_exec_sessions s on r.session_id = s.session_id
where s.is_user_process = 0x1
group by r.session_id, r.request_id, r.sql_handle, r.plan_handle, 
r.statement_start_offset, r.statement_end_offset
having max(isnull(exec_context_id, 0)) > 0

