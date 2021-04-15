use master
go

CREATE proc sp_perfmon_name
as
/*
Procedure to get the perfmon labels for the instances
of sqlservr.exe running on a server as they appear in
perfmon as sqlservr#1,sqlservr#2 etc and only by coincidence
will these map to the "correct"instance. The labels are
decided by the order of the Process ID's

*/
set nocount on
declare @cmd varchar(500)
declare @ret int
declare @hr int
declare @fso int 
declare @file int 
declare @filename varchar(100)
declare @spid varchar(4) 

create table #temp(txt varchar(100))
create table #results(i int identity(1,1) PRIMARY KEY,instance varchar(20),PID int)

set @spid = CAST(@@SPID as varchar(4))
set @filename = 'c:\tempwmi'+ @spid + '.vbs'

--Create temp VBS file
set @cmd = 'On Error Resume Next' + CHAR(13) +
           'Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")' + CHAR(13) +
           'Set colItems = objWMIService.ExecQuery("Select * from Win32_Service where Name = ''MSSQLSERVER'' OR (Name >=''MSSQL$A'' AND Name < ''MSSQL$Z'')",,48)' + CHAR(13) +
           'For Each objItem in colItems' + CHAR(13) +
           'Wscript.Echo objItem.Name & "," & objItem.ProcessId' + CHAR(13) +
           'Next'

EXEC @hr=sp_OACreate 'Scripting.FileSystemObject',@fso OUT 
IF @hr <> 0 EXEC sp_OAGetErrorInfo @fso

EXEC @hr=sp_OAMethod @fso, 'CreateTextFile',@file OUT, @filename , 'True'
IF @hr <> 0 EXEC sp_OAGetErrorInfo @fso  

EXEC @hr=sp_OAMethod @file,'Write',NULL,@cmd
IF @hr <> 0 EXEC sp_OAGetErrorInfo @file

EXEC @hr=sp_OADestroy @file 
IF @hr <> 0 EXEC sp_OAGetErrorInfo @file

EXEC @hr=sp_OADestroy @fso 
IF @hr <> 0 EXEC sp_OAGetErrorInfo @fso


-- get services + PID's
set @cmd = 'cscript //nologo ' + @filename
insert #temp
exec @ret = master..xp_cmdshell @cmd
If @ret<>0
begin
   raiserror('Error running temp VBS file at %s',16,1,@filename)
   drop table #temp
   drop table #results
   set @cmd = 'del /Q ' + @filename
   exec @ret = master..xp_cmdshell @cmd,no_output
   return 1
end

--Perfmon lables processes based on PID order
insert #results(instance,PID)
select LEFT(txt,(CHARINDEX(',',txt)-1)),RIGHT(txt,(LEN(txt)-CHARINDEX(',',txt)))
from #temp
where txt is not null
order by RIGHT(txt,(LEN(txt)-CHARINDEX(',',txt)))

select CASE WHEN i = 1 THEN 'sqlservr' ELSE 'sqlservr#' + CAST((i-1) as varchar(2)) END AS 'Perfmon',
instance as 'Instance',PID as 'Process ID' from #results
order by 1

--clean up
drop table #temp
drop table #results
set @cmd = 'del /Q ' + @filename
exec @ret = master..xp_cmdshell @cmd,no_output
If @ret<>0
begin
   raiserror('Error deleting temp VBS file at %s',16,1,@filename)
   return 1
end

return
go

--Usage of the Script
exec sp_perfmon_name


