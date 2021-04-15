/*
Get Record Counts for All Tables in Every Database

This stored procedure produces a report of record counts for every table on your server.  
The record count report is organized by database, and table name. 

*/

CREATE PROCEDURE usp_get_record_counts AS
-- Written By: Greg Larsen
-- Date: 2/28/2002


declare @CMD char(2000)
declare @DB  varchar(100)
set nocount on
declare db cursor for 
select name from master..sysdatabases
 open db
fetch next from db into @db

WHILE @@FETCH_STATUS = 0
BEGIN
print 'Record Counts for database ' + @DB 
set @CMD = 'SELECT ' + char(39) + @DB + char(39) + 'as DB, rows, b.name FROM ' + @DB + '..sysindexes a , ' + @DB + '..sysobjects b ' +
  'WHERE a.id = b.id and type=''u'' AND indid < 2 order by b.name'
exec (@CMD)
fetch next from db into @db
end
close db
deallocate db

