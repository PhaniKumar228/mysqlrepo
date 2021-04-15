/*
Retrieve Waiter List Information

Description

Sample script that retrieves wait list information. The Waiter list contains resource waits waiting for the resource. Once a resource is available the corresponding session_id is moved to the runnable queue. Signal waits is the time spent in the runnable queue. This script requires Microsoft SQL Server 2005. 

Script Code


*/

select session_id
		, exec_context_id
		, wait_type
		, wait_duration_ms
		, blocking_session_id
from sys.dm_os_waiting_tasks
where session_id > 50
order by session_id, exec_context_id

