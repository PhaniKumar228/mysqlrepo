/*
View all settings for all databases on your server

My stored procedure, sp_dbsettings, allows you to view, in a cross-tabular format, all the common options and their values for all the databases on your server.  

Optionally, you can pass a database name as an argument if you just want to view the settings for one database (i.e., EXEC sp_dbsettings 'Northwind').  Otherwise it shows info for all databases.

Note: On SQL 2000, this procedure could easily be re-written as a UDF, if the user desires more control over the columns displayed, etc.) 

*/

use master
go

create procedure sp_dbsettings
@db sysname = null

as

select name, 
min(case status & 1 when 1 then 'TRUE' else 'False' end) as [autoclose],
min(case status & 4 when 4 then 'TRUE' else 'False' end) as [select into/bulkcopy],
min(case status & 8 when 8 then 'TRUE' else 'False' end) as [trunc. log on chkpt],
min(case status & 16 when 16 then 'TRUE' else 'False' end) as [torn page detection],
min(case status & 32 when 32 then 'TRUE' else 'False' end) as [loading],
min(case status & 64 when 64 then 'TRUE' else 'False' end) as [pre recovery],
min(case status & 128 when 128 then 'TRUE' else 'False' end) as [recovering],
min(case status & 256 when 256 then 'TRUE' else 'False' end) as [Falset recovered],
min(case status & 512 when 512 then 'TRUE' else 'False' end) as [offline],
min(case status & 1024 when 1024 then 'TRUE' else 'False' end) as [read only],
min(case status & 2048 when 2048 then 'TRUE' else 'False' end) as [dbo use only],
min(case status & 4096 when 4096 then 'TRUE' else 'False' end) as [single user],
min(case status & 32768 when 32768 then 'TRUE' else 'False' end) as [emergency mode],
min(case status & 4194304 when 4194304 then 'TRUE' else 'False' end) as [autoshrink],
min(case status & 1073741824 when 1073741824 then 'TRUE' else 'False' end) as [cleanly shutdown],
min(case status2 & 16384 when 16384 then 'TRUE' else 'False' end) as [ANSI null default],
min(case status2 & 65536 when 65536 then 'TRUE' else 'False' end) as [concat null yields null],
min(case status2 & 131072 when 131072 then 'TRUE' else 'False' end) as [recursive triggers],
min(case status2 & 1048576 when 1048576 then 'TRUE' else 'False' end) as [default to local cursor],
min(case status2 & 8388608 when 8388608 then 'TRUE' else 'False' end) as [quoted identifier],
min(case status2 & 33554432 when 33554432 then 'TRUE' else 'False' end) as [cursor close on commit],
min(case status2 & 67108864 when 67108864 then 'TRUE' else 'False' end) as [ANSI nulls],
min(case status2 & 268435456 when 268435456 then 'TRUE' else 'False' end) as [ANSI warnings],
min(case status2 & 536870912 when 536870912 then 'TRUE' else 'False' end) as [full text enabled]

from sysdatabases

where (name = @db or @db is null)

group by name




