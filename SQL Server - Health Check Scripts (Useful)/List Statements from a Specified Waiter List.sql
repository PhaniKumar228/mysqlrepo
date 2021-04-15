/*
List Statements from a Specified Waiter List

Description

Sample stored procedure that lists all statements from the waiter list that match @wait_type. If @wait_type is null, the script lists all statements in the waiter list. This stored procedure requires Microsoft SQL Server 2005. 

Script Code


*/

if exists (select * from sys.objects where object_id = object_id(N'[dbo].[get_statements_from_waiter_list]') and OBJECTPROPERTY(object_id, N'IsProcedure') = 1)
	drop procedure [dbo].[get_statements_from_waiter_list]
go

create proc get_statements_from_waiter_list (@wait_type nvarchar(60)=NULL)
as
select 
	    r.wait_type
		,r.wait_time
        ,SUBSTRING(qt.text,r.statement_start_offset/2, 
			(case when r.statement_end_offset = -1 
			then len(convert(nvarchar(max), qt.text)) * 2 
			else r.statement_end_offset end -r.statement_start_offset)/2) 
		as query_text
		,qt.dbid, dbname=db_name(qt.dbid)
		,qt.objectid
		,r.sql_handle
		,r.plan_handle
FROM sys.dm_exec_requests r
cross apply sys.dm_exec_sql_text(r.sql_handle) as qt
where r.session_id > 50
  and r.wait_type = isnull(upper(@wait_type),r.wait_type)
go

exec get_statements_from_waiter_list

