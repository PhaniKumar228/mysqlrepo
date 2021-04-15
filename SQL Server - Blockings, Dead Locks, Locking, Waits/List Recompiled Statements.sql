/*
List Recompiled Statements

Description

Sample script that lists recompiled statements. A statement gets recompiled each time the plan generation number is incremented. This script requires Microsoft SQL Server 2005. 

Script Code


*/

select top 25
	--sql_text.text,
	sql_handle,
	plan_generation_num,
	substring(text,qs.statement_start_offset/2, 
			(case when qs.statement_end_offset = -1 
			then len(convert(nvarchar(max), text)) * 2 
			else qs.statement_end_offset end - qs.statement_start_offset)/2) 
		as stmt_executing,
	execution_count,
	dbid,
	objectid 
from sys.dm_exec_query_stats as qs
	Cross apply sys.dm_exec_sql_text(sql_handle) sql_text
where plan_generation_num >1
order by sql_handle, plan_generation_num

