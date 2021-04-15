/*
Retrieve SQL Text and XML Plans

Description

Sample stored procedure that retrieves the SQL text and XML plan using the sql_handle and plan_handle. This stored procedure requires Microsoft SQL Server 2005. 

Script Code


*/

select 
(select text from sys.dm_exec_sql_text(put_sql_handle_here)) as sql_text
,(select query_plan from sys.dm_exec_query_plan(put_plan_handle_here)) as query_plan
go

