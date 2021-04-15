set nocount on
if exists (select * from tempdb.dbo.sysobjects where name='##msver')
	drop table ##msver
Create table ##msver ([index] int,[Name] varchar(60),Internal_Value int null,Character_Value varchar(255) null)
insert ##msver
exec master.dbo.xp_msver
if (select left(Character_Value,1) from ##msver where [index]=2) in ('7','8','9')
begin
	
	--
	if exists (select * from tempdb.dbo.sysobjects where name = '##DatabaseProperties')
		drop table ##DatabaseProperties

	CREATE TABLE ##DatabaseProperties (
		[Servername] [varchar] (60)  NOT NULL ,
		[Dbname] [varchar] (60)  NOT NULL ,
		[CaptureDate] [datetime] NOT NULL ,
		[IsAnsiNullDefault] [int] NOT NULL ,
		[IsAnsiNullsEnabled] [int] NOT NULL ,
		[IsAnsiWarningsEnabled] [int] NOT NULL ,
		[IsAutoClose] [int] NOT NULL ,
		[IsAutoCreateStat[Istics] [int] NOT NULL ,
		[IsAutoShrink] [int] NOT NULL ,
		[IsAutoUpdateStat[Istics] [int] NOT NULL ,
		[IsBulkCopy] [int] NULL , --7
		[IsCloseCursorsOnCommitEnabled] [int] NOT NULL ,
		[IsDboOnly] [int] NULL , --7
		[IsDetached] [int] NULL , --7
		[IsEmergencyMode] [int] NULL , --7
		[IsFulltextEnabled] [int] NULL , 
		[IsInLoad] [int] NULL , --7
		[IsInRecovery] [int] NULL , --7
		[IsInStandBy] [int] NOT NULL ,
		[IsLocalCursorsDefault] [int] NOT NULL ,
		[IsNotRecovered] [int] NULL , --7
		[IsNullConcat] [int] NOT NULL ,
		[IsOffline] [int] NULL , --7
		[IsQuotedIdentifiersEnabled ] [int] NOT NULL ,
		[IsReadOnly] [int] NULL , --7
		[IsRecursiveTriggersEnabled ] [int] NOT NULL ,
		[IsShutDown ] [int] NULL ,--7
		[IsSingleUser ] [int] NULL ,--7
		[IsSuspect] [int] NULL , --7
		[IsTruncLog] [int] NULL , --7
		[Version] [int] 
		)
	---
	declare @D varchar(60),@getdate datetime
	set @getdate=getdate()
	select @D=min(name) from master.dbo.sysdatabases
	while @D is not null
	begin
		insert ##DatabaseProperties
		SELECT 
			@@servername as Servername,
			@D as Dbname,
			@getdate as capturedate,
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsAnsiNullDefault')),1) as IsAnsiNullDefault,
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsAnsiNullsEnabled')),1) as IsAnsiNullsEnabled,
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsAnsiWarningsEnabled')),1) as IsAnsiWarningsEnabled,
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsAutoClose')),1) as IsAutoClose,
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsAutoCreateStatistics')),1) as IsAutoCreateStatistics,
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsAutoShrink')),1) as IsAutoShrink,
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsAutoUpdateStatistics')),1) as IsAutoUpdateStatistics,
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsBulkCopy')),1) as IsBulkCopy,
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsCloseCursorsOnCommitEnabled')),1) as IsCloseCursorsOnCommitEnabled,
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsDboOnly')),1) as IsDboOnly,--7
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsDetached')),1) as IsDetached, --7
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsEmergencyMode')),1) as IsEmergencyMode, --7
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsFulltextEnabled')),1) as IsFulltextEnabled, 
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsInLoad')),1) as IsInLoad, --7
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsInRecovery')),1) as IsInRecovery, --7
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsInStandBy')),1) as IsInStandBy,
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsLocalCursorsDefault')),1) as IsLocalCursorsDefault,
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsNotRecovered')),1) as IsNotRecovered, --7
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsNullConcat')),1) as IsNullConcat,
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsOffline')),1) as IsOffline, --7
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsQuotedIdentifiersEnabled ')),1) as IsQuotedIdentifiersEnabled,
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsReadOnly')),1) as IsReadOnly, --7
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsRecursiveTriggersEnabled ')),1) as IsRecursiveTriggersEnabled,
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsShutDown ')),1) as IsShutDown,--7
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsSingleUser ')),1) as IsSingleUser,--7
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsSuspect')),1) as IsSuspect, --7
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'IsTruncLog')),1) as IsTruncLog, --7
			isnull(CONVERT(int,DATABASEPROPERTY (@D,'Version')),1) as version
		select @D=min(name) from master.dbo.sysdatabases where name>@D
	end
	select * from ##DatabaseProperties
	if exists (select * from tempdb.dbo.sysobjects where name = '##DatabaseProperties')
		drop table ##DatabaseProperties
	if exists (select * from tempdb.dbo.sysobjects where name='##msver')
		drop table ##msver

end	
