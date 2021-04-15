/*
Check user activity

This stored procedure is another monitoring utility that can be executed periodically as a sql server agent job. 
The procedure checks if there are any open connections, and if there was any recent user activity within a given 
period of time in a given (or any) database by a given (or any/any except given) login from a certain group of hosts
(or any host)via a particular (or any) application. 
An error will be raised if the last executed batch occurred earlier than defined in @pThresholdMinutes.
*/

drop  PROCEDURE uspCheckActivity
go
CREATE PROCEDURE uspCheckActivity
@pDbName sysname=NULL,
@pLoginame sysname=NULL,
@pExcludeLogin sysname=NULL,
@pHostnamePattern varchar(128)=NULL,
@pApplication varchar(128)=NULL,
@pThresholdMinutes smallint=2
/****** 
Server: Any
Database:DBAservice
Checks if there are any open connections, and if there was any recent user activity within a given period of time
in a given (or any) database by a given (or any/any except given) login from a certain group of hosts (or any host)
via a particular (or any) application. 
An error will be raised if the last executed batch occurred earlier than defined in @pThresholdMinutes.
This utility is used for server monitoring. It can be executed periodically in a job 
NOTE: It is assumed that only one instance of uspCheckActivity is executed at a time
******/
AS
Set NOCOUNT ON
DECLARE @MinSinceLastBatch int,@SelfSpid int, @str varchar(512)

--Make sure the database exists
If not exists (select * from master..sysdatabases where name=@pDbName or @pDbName IS  NULL)
BEGIN
	Select @str='Database '+@pDbName+' was not found on server '+@@servername
	Raiserror(@str, 16,2)
	Return -1
END

--Eliminate own process
select spid into #SPIDs from master.dbo.sysprocesses 
where status='runnable' and cmd like 'SELECT INTO%' 
Create table #InputBuffers(type varchar(128),Param varchar(128),EventInfo varchar(1024))
WHILE  (select count(*) from #SPIDs)>0
BEGIN
	select @SelfSpid=max(spid) from #SPIDs
	Select @str='DBCC inputbuffer ('+str(@SelfSpid)+')'
	INSERT #InputBuffers exec (@str)
	If exists (select 1 from #InputBuffers where EventInfo like '%uspCheckActivity%') Delete #SPIDs
	ELSE Delete #SPIDs where spid=@SelfSpid
END
--select  * FROM #InputBuffers
--select @SelfSpid as SelfSpid
drop table #InputBuffers
drop table #SPIDs
------
Select @MinSinceLastBatch=datediff(mi,max(last_batch),getdate()) from master.dbo.sysprocesses
WHERE
(db_name(dbid)=@pDbName or @pDbName IS NULL)
AND (loginame =@pLoginame or @pLoginame IS NULL)
AND (hostname like @pHostnamePattern+'%' or @pHostnamePattern is NULL)
AND(program_name=@pApplication OR @pApplication IS NULL)
AND (loginame <>@pExcludeLogin or @pExcludeLogin IS NULL)
and (spid<>@SelfSpid or @SelfSpid IS NULL)

If Isnull(@MinSinceLastBatch,1000000)>=@pThresholdMinutes
Begin
	Select @str='No activity or connections of '+isnull('login '+Rtrim(@pLoginame),'any login')+' in '
	+Isnull('database '+Rtrim(@pDbName),'any database')+' from '+Isnull('host(s) '+Rtrim(@pHostnamePattern)+'[...]','any host')
	+' via '+Isnull('application '+Rtrim(@pApplication),'any application')
	+ISNULL(' for '+rtrim(cast(@MinSinceLastBatch as char))+' minute(s)',' found.')
	Raiserror(@str, 15,1)
End
Set NOCOUNT OFF	
GO