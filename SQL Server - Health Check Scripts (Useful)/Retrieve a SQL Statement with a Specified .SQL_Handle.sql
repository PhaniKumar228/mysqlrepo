/*
Retrieve a SQL Statement with a Specified .SQL_Handle

Description

Sample stored procedure that retrieves a SQL statement and statistics when supplied with the .Sql_handle, the statement starting offset, and the statement ending offset. This stored procedure requires Microsoft SQL Server 2005. 

Script Code


*/

create proc get_sql_text (@sql_handle varbinary(64)=NULL
					,@stmtstart int=NULL
					,@stmtend int =NULL)
as

if @sql_handle is NULL 
	or @stmtstart is NULL 
	or @stmtend is NULL
begin
	print 'you must provide sqlhandle, stmtstart, and stmtend'
	return -999
end

select 
		 substring(qt.text,s.statement_start_offset/2, 
			(case when s.statement_end_offset = -1 
			then len(convert(nvarchar(max), qt.text)) * 2 
			else s.statement_end_offset end -s.statement_start_offset)/2) 
		as "SQL statement"
		,s.statement_start_offset
		,s.statement_end_offset
		,batch=qt.text
		,qt.dbid
		,qt.objectid
		,s.execution_count
		,s.total_worker_time
		,s.total_elapsed_time
		,s.total_logical_reads
		,s.total_physical_reads
		,s.total_logical_writes
from sys.dm_exec_query_stats s
cross apply sys.dm_exec_sql_text(s.sql_handle) as qt
where s.sql_handle = @sql_handle
and s.statement_start_offset = @stmtstart
and s.statement_end_offset = @stmtend
go
exec get_sql_text @sql_handle = 0x0300050014ba910b5a89af00bb9600000100000000000000,@stmtstart = 84,@stmtend = 210
go
