select * from sys.dm_exec_sessions where status <>'sleeping'
select percent_complete,* from sys.dm_exec_requests where session_id in(64)
select * from sys.dm_os_waiting_tasks where session_id in(64)
select * from sys.dm_exec_sql_text(0x020000006EE8681F422C39B41A58A061B06EACDBC559FF9D)

