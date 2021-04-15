use msdb
go
SELECT SVR=@@Servername
go

IF NOT EXISTS (SELECT * FROM sys.server_principals WHERE name = N'ECM-GHQ\DBASG')
	CREATE LOGIN [ECM-GHQ\DBASG] FROM WINDOWS WITH DEFAULT_DATABASE=[master], DEFAULT_LANGUAGE=[us_english]
GO
EXEC master..sp_addsrvrolemember @loginame = N'ECM-GHQ\DBASG', @rolename = N'sysadmin'
GO

SELECT srvname=@@servername,owner, plan_name, date_created 
-- select *
FROM msdb.dbo.sysdbmaintplans
where owner <> 'sa'
UNION
select srvname=@@servername,owner, name, create_date
-- select *
from msdb.dbo.sysmaintplan_plans
where owner <> 'sa'
order by srvname,plan_name
-- update msdb.dbo.sysdbmaintplans set owner = 'sa' where owner <> 'sa'
-- update msdb.dbo.sysdtspackages90 set ownersid = 0x01 WHERE folderid = '08aa12d5-8f98-4dab-a4fc-980b150a5dc8' and packagetype = 6 and ownersid <> 0x01
/*
exec sp_helptext sysdbmaintplans
exec sp_helptext sysmaintplan_plans
exec sp_depends sysdtspackages90
select distinct object_name(id) from syscomments where text like '%sysdtspackages90%'
select * from msdb.dbo.sysdtspackages90 WHERE folderid = '08aa12d5-8f98-4dab-a4fc-980b150a5dc8' and packagetype = 6
*/

SELECT	s.name AS [name],
		s.description AS [description],
		s.createdate AS [create_date],
		suser_sname(s.ownersid) AS [owner]
FROM   msdb.dbo.sysdtspackages90 AS s
WHERE   (s.folderid = '08aa12d5-8f98-4dab-a4fc-980b150a5dc8' and s.packagetype = 6)

SELECT * FROM msdb.dbo.sysdtspackages90 where suser_sname(ownersid) like '%welldata%'

begin tran
	update msdb.dbo.sysdtspackages90 set ownersid =0x01
	where suser_sname(ownersid) like '%welldata%'
commit
go

-- ensure DBAServices exists
IF NOT EXISTS (SELECT name FROM msdb.dbo.sysoperators WHERE name = N'DBAServices')
	EXEC dbo.sp_add_operator
		@name			= N'DBAServices'
	,	@enabled		= 1
	,	@email_address	= N'DBAServices@europeancredit.com'
GO
EXEC sp_MSsetalertinfo @failsafeoperator=N'DBAServices'
GO

-- change jobs (replaces Nick's code)
DECLARE jobcur CURSOR FOR
	select	job_name=name
	from	msdb..sysjobs 
	where	suser_sname(owner_sid) like '%welldata%'
	order by name
declare @jobname sysname
OPEN jobcur
FETCH NEXT FROM jobcur INTO @jobname
WHILE @@FETCH_STATUS = 0
BEGIN
	PRINT @jobname
	EXEC dbo.sp_update_job
		@job_name=@jobname
	,	@owner_login_name=N'sa'
	,	@notify_level_email = 2
	,	@notify_email_operator_name=N'DBAServices'
	FETCH NEXT FROM jobcur INTO @jobname
END
CLOSE jobcur
DEALLOCATE jobcur
go

-- replace all Welldata operators by DBAServices
DECLARE opercur CURSOR FOR
	select	name
	from	dbo.sysoperators
	where	name like '%welldata%'
	order by name
declare @opername sysname
OPEN opercur
FETCH NEXT FROM opercur INTO @opername
WHILE @@FETCH_STATUS = 0
BEGIN
	PRINT @opername
	EXEC dbo.sp_delete_operator
			@name					= @opername
		,	@reassign_to_operator	= N'DBAServices'
	FETCH NEXT FROM opercur INTO @opername
END
CLOSE opercur
DEALLOCATE opercur
go

-- drop WD accounts
IF EXISTS (SELECT * FROM sys.server_principals WHERE name = N'ECM-GHQ\WellDataDBA')
	DROP LOGIN [ECM-GHQ\WellDataDBA]
GO

IF EXISTS (SELECT * FROM sys.server_principals WHERE name = N'wdmonitor')
	DROP LOGIN [wdmonitor]
GO

-- any unclaimed db's to be owned by sa
DECLARE dbcur CURSOR FOR
	select name
	from master..sysdatabases
	where suser_sname(sid) is NULL
	order by name
declare @dbname sysname
OPEN dbcur
FETCH NEXT FROM dbcur INTO @dbname
WHILE @@FETCH_STATUS = 0
BEGIN
	PRINT @dbname
exec('USE ['+@dbname+']; EXEC dbo.sp_changedbowner @loginame = N''sa'', @map = false')
	FETCH NEXT FROM dbcur INTO @dbname
END
CLOSE dbcur
DEALLOCATE dbcur
go
