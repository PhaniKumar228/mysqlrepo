sp_who2 active
select * from sys.dm_exec_sessions where session_id=65  
select percent_complete,* from sys.dm_exec_requests where session_id=65  
select * from sys.dm_os_waiting_tasks 