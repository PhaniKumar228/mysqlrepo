/*
List Currently-Executing Parallel Plans

Description

Sample script that finds currently-executing parallel plans (indicated by an Exec_context_id greater than 0).This script, contributed by Microsoft's Tom Davidson, requires SQL Server 2005. 

Script Code


*/

select 
  qs.sql_handle, 
  qs.statement_start_offset, 
  qs.statement_end_offset, 
  q.dbid,
  q.objectid,
  q.number,
  q.encrypted,
  q.text
from sys.dm_exec_query_stats qs
	cross apply sys.dm_exec_sql_text(qs.plan_handle) as q
where qs.total_worker_time > qs.total_elapsed_time

